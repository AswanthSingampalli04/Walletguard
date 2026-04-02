from fastapi import FastAPI
from pydantic import BaseModel
import base64
import pytesseract
from PIL import Image
import io

app = FastAPI()


# If using Windows, set Tesseract path
pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"


class ImageRequest(BaseModel):
    image_base64: str


@app.get("/")
def home():
    return {"message": "OCR Backend Running"}


@app.post("/ocr")
async def extract_text(data: ImageRequest):
    try:
        # Decode Base64
        image_bytes = base64.b64decode(data.image_base64)

        # Convert bytes → Image
        image = Image.open(io.BytesIO(image_bytes))

        # Run Tesseract OCR
        text = pytesseract.image_to_string(image)

        return {
            "status": "success",
            "text": text.strip()
        }

    except Exception as e:
        return {
            "status": "error",
            "message": str(e)
        }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5001)