"""
Mise en Pic — Cloud Functions (Gen 2, Python).

Two endpoints:
  1. generate_recipe  — accepts photo + modifier, calls Gemini/Imagen, returns recipe.
  2. fulfill_purchase — RevenueCat webhook, increments user credits.
"""

import base64
import io
import json
import logging
import os
from concurrent.futures import ThreadPoolExecutor, as_completed

import firebase_admin
from firebase_admin import auth as firebase_auth, firestore
from firebase_functions import https_fn, options
from google import genai
from google.genai import types as genai_types
from PIL import Image

firebase_admin.initialize_app()
db = firestore.client()
logger = logging.getLogger(__name__)

# ── Constants ────────────────────────────────────────────────────

_FREE_CREDITS = 3
_BG_COLOR = "#E8EFE6"

_TEXT_SYSTEM_PROMPT = (
    "You identify food from photos and return structured JSON recipes.\n"
    'NOT FOOD? Return ONLY: {"notFood":true,"message":"<witty one-liner>"}.\n'
    "IS FOOD: Create a recipe FOR the item shown (hot sauce→hot sauce recipe, "
    "bread→bread recipe). Be specific — name the exact dish, cuisine, variant. "
    "Never refuse. No brand names. Give fun, evocative dish names.\n"
    "Each ingredient: short visual tag (2-4 words, e.g. \"golden slab, soft\"). "
    "Julia Child style: precise, warm. "
    "8-10 method steps, 1 line each, action-oriented with sensory cues."
)

_STAPLES = {
    "salt", "pepper", "black pepper", "oil", "olive oil", "vegetable oil",
    "canola oil", "cooking oil", "water", "ice", "flour", "all-purpose flour",
    "sugar", "granulated sugar", "brown sugar", "butter", "unsalted butter",
    "garlic", "kosher salt", "sea salt", "cornstarch", "baking powder",
    "baking soda",
}

_CREDIT_MAP = {
    "credits_10_pack": 10,
    "credits_100_pack": 100,
}


# ── Helpers ──────────────────────────────────────────────────────

def _get_gemini_client() -> genai.Client:
    """Create a Gemini client using the API key from environment."""
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY not set in function environment.")
    return genai.Client(api_key=api_key)


def _downscale_image(image_bytes: bytes, max_dim: int = 512) -> bytes:
    """Downscale image so its longest side is at most max_dim."""
    img = Image.open(io.BytesIO(image_bytes))
    w, h = img.size
    if w <= max_dim and h <= max_dim:
        return image_bytes
    scale = max_dim / max(w, h)
    new_size = (round(w * scale), round(h * scale))
    img = img.resize(new_size, Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=85)
    return buf.getvalue()


def _featured_indices(ingredients: list[dict]) -> list[int]:
    """Return indices of non-staple ingredients (max 6)."""
    indices = []
    for i, ing in enumerate(ingredients):
        name = ing.get("name", "").lower().strip()
        if name not in _STAPLES:
            indices.append(i)
        if len(indices) >= 6:
            break
    return indices


def _verify_token(request: https_fn.Request) -> str:
    """Extract and verify Firebase ID token. Returns UID."""
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="Missing or invalid Authorization header.",
        )
    token = auth_header.removeprefix("Bearer ")
    decoded = firebase_auth.verify_id_token(token)
    return decoded["uid"]


# ── Generate Recipe ──────────────────────────────────────────────

@https_fn.on_request(
    cors=options.CorsOptions(cors_origins="*", cors_methods=["POST"]),
    memory=options.MemoryOption.GB_1,
    timeout_sec=120,
    secrets=["GEMINI_API_KEY"],
)
def generate_recipe(request: https_fn.Request) -> https_fn.Response:
    """
    POST /generate_recipe
    Headers: Authorization: Bearer <firebase_id_token>
    Body: {"photo": "<base64>", "modifier": "standard"}
    Returns: {"recipe": {...}, "dishImage": "<base64>", "gridImage": "<base64>"}
    """
    if request.method != "POST":
        return https_fn.Response("Method not allowed", status=405)

    # ── Auth ──
    try:
        uid = _verify_token(request)
    except Exception:
        return https_fn.Response(
            json.dumps({"error": "unauthenticated"}),
            status=401,
            content_type="application/json",
        )

    # ── Credit check (atomic) ──
    user_ref = db.collection("users").document(uid)

    @firestore.transactional
    def check_and_decrement(transaction, ref):
        snap = ref.get(transaction=transaction)
        if not snap.exists:
            # First-time user: seed with free credits.
            transaction.set(ref, {
                "available_credits": _FREE_CREDITS,
                "total_generated": 0,
                "created_at": firestore.SERVER_TIMESTAMP,
            })
            return _FREE_CREDITS

        credits = snap.get("available_credits") or 0
        if credits <= 0:
            return 0

        # Don't decrement yet — we decrement after successful generation.
        return credits

    transaction = db.transaction()
    credits = check_and_decrement(transaction, user_ref)
    if credits <= 0:
        return https_fn.Response(
            json.dumps({"error": "no_credits"}),
            status=403,
            content_type="application/json",
        )

    # ── Parse request ──
    body = request.get_json(silent=True) or {}
    photo_b64 = body.get("photo")
    modifier = body.get("modifier", "standard")

    if not photo_b64:
        return https_fn.Response(
            json.dumps({"error": "missing_photo"}),
            status=400,
            content_type="application/json",
        )

    try:
        photo_bytes = base64.b64decode(photo_b64)
    except Exception:
        return https_fn.Response(
            json.dumps({"error": "invalid_photo_encoding"}),
            status=400,
            content_type="application/json",
        )

    # ── Call 1: Gemini text (recipe JSON) ──
    client = _get_gemini_client()
    small_photo = _downscale_image(photo_bytes, max_dim=512)

    recipe_prompt = (
        f"Identify the specific food/dish and create a recipe for it.\n"
        f"Diet: {modifier}.\n"
        f'JSON: {{"dishName":"CAPS NAME","tagline":"one line",'
        f'"prepTime":"20 min","cookTime":"35 min","servings":"4",'
        f'"caloriesPerServing":450,'
        f'"ingredients":[{{"emoji":"🧈","amount":"2 tbsp","name":"unsalted butter",'
        f'"visual":"golden, soft"}}],'
        f'"method":"1. Step... 2. Step..."}}\n'
        f"Keep visuals to 2-4 words. Method steps: 1 line max.\n"
        f"8-15 ingredients. 8-10 method steps. Adjust for {modifier} diet."
    )

    try:
        text_response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=[
                genai_types.Content(
                    parts=[
                        genai_types.Part.from_text(recipe_prompt),
                        genai_types.Part.from_bytes(
                            data=small_photo,
                            mime_type="image/jpeg",
                        ),
                    ],
                ),
            ],
            config=genai_types.GenerateContentConfig(
                system_instruction=_TEXT_SYSTEM_PROMPT,
                temperature=0.5,
                max_output_tokens=4096,
                response_mime_type="application/json",
            ),
        )
    except Exception as e:
        logger.error(f"Gemini text error: {e}")
        return https_fn.Response(
            json.dumps({"error": "generation_failed", "message": str(e)}),
            status=500,
            content_type="application/json",
        )

    raw_text = text_response.text
    if not raw_text:
        return https_fn.Response(
            json.dumps({"error": "empty_response"}),
            status=500,
            content_type="application/json",
        )

    try:
        recipe = json.loads(raw_text)
    except json.JSONDecodeError as e:
        return https_fn.Response(
            json.dumps({"error": "invalid_json", "message": str(e)}),
            status=500,
            content_type="application/json",
        )

    # Not food — don't decrement credits.
    if recipe.get("notFood"):
        return https_fn.Response(
            json.dumps(recipe),
            status=200,
            content_type="application/json",
        )

    recipe["modifier"] = modifier

    # ── Call 2: Imagen illustrations (dish + grid, parallel) ──
    ingredients = recipe.get("ingredients", [])
    featured = _featured_indices(ingredients)
    ingredient_names = ", ".join(
        ingredients[i]["name"] for i in featured if i < len(ingredients)
    )
    dish_name = recipe.get("dishName", "dish")

    dish_prompt = (
        f'Watercolor & ink illustration of "{dish_name}": '
        f"the finished dish, vibrant and appetizing, centered on a "
        f"solid {_BG_COLOR} background. Bold ink outlines, gouache "
        f"watercolor fills, charming folk-art recipe-journal style. "
        f"No text, no borders, no photorealism."
    )

    grid_prompt = (
        f"Watercolor & ink ingredient sprites on solid {_BG_COLOR} "
        f"background: {ingredient_names}. Each ingredient drawn separately "
        f"with space between them, arranged in a loose grid. Bold ink "
        f"outlines, gouache fills, folk-art recipe-journal style. "
        f"No text, no labels, no borders, no photorealism."
    )

    dish_image_b64 = None
    grid_image_b64 = None

    def _generate_image(prompt: str) -> str | None:
        """Call Imagen 4.0 Fast and return base64 PNG, or None."""
        try:
            resp = client.models.generate_images(
                model="imagen-4.0-fast-generate-001",
                prompt=prompt,
                config=genai_types.GenerateImagesConfig(
                    number_of_images=1,
                    aspect_ratio="1:1",
                    person_generation="DONT_ALLOW",
                ),
            )
            if resp.generated_images:
                return base64.b64encode(
                    resp.generated_images[0].image.image_bytes
                ).decode()
        except Exception as e:
            logger.warning(f"Imagen error: {e}")
        return None

    # Run both image calls in parallel.
    with ThreadPoolExecutor(max_workers=2) as pool:
        dish_future = pool.submit(_generate_image, dish_prompt)
        grid_future = pool.submit(_generate_image, grid_prompt)
        dish_image_b64 = dish_future.result()
        grid_image_b64 = grid_future.result()

    # ── Decrement credit (only after successful generation) ──
    user_ref.update({
        "available_credits": firestore.Increment(-1),
        "total_generated": firestore.Increment(1),
    })

    return https_fn.Response(
        json.dumps({
            "recipe": recipe,
            "dishImage": dish_image_b64,
            "gridImage": grid_image_b64,
            "featuredIndices": featured,
        }),
        status=200,
        content_type="application/json",
    )


# ── Fulfill Purchase (RevenueCat Webhook) ────────────────────────

@https_fn.on_request(
    cors=options.CorsOptions(cors_origins="*", cors_methods=["POST"]),
    secrets=["REVENUECAT_WEBHOOK_SECRET"],
)
def fulfill_purchase(request: https_fn.Request) -> https_fn.Response:
    """
    POST /fulfill_purchase
    Called by RevenueCat webhook on successful purchase.
    """
    if request.method != "POST":
        return https_fn.Response("Method not allowed", status=405)

    # Validate webhook authorization.
    expected_secret = os.environ.get("REVENUECAT_WEBHOOK_SECRET", "")
    auth_header = request.headers.get("Authorization", "")
    if auth_header != f"Bearer {expected_secret}":
        return https_fn.Response("Unauthorized", status=401)

    body = request.get_json(silent=True) or {}
    event = body.get("event", {})
    event_type = event.get("type", "")

    # Only process initial purchases (consumables don't renew).
    if event_type not in ("INITIAL_PURCHASE", "NON_RENEWING_PURCHASE"):
        return https_fn.Response("OK", status=200)

    # Deduplicate by event ID.
    event_id = event.get("id")
    if event_id:
        event_ref = db.collection("processed_events").document(event_id)
        if event_ref.get().exists:
            return https_fn.Response("Already processed", status=200)
        event_ref.set({"processed_at": firestore.SERVER_TIMESTAMP})

    # Extract user and product info.
    app_user_id = event.get("app_user_id", "")
    product_id = event.get("product_id", "")

    if not app_user_id or not product_id:
        logger.warning(f"Missing app_user_id or product_id in webhook: {event}")
        return https_fn.Response("Missing fields", status=400)

    credits_to_add = _CREDIT_MAP.get(product_id)
    if credits_to_add is None:
        logger.warning(f"Unknown product_id: {product_id}")
        return https_fn.Response("Unknown product", status=400)

    # Increment credits.
    user_ref = db.collection("users").document(app_user_id)
    user_ref.set(
        {"available_credits": firestore.Increment(credits_to_add)},
        merge=True,
    )

    logger.info(
        f"Fulfilled {credits_to_add} credits for user {app_user_id} "
        f"(product: {product_id}, event: {event_id})"
    )

    return https_fn.Response("OK", status=200)
