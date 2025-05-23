import os
import torch
import tempfile
import shutil
from fastapi import FastAPI, UploadFile, File, HTTPException
from transformers import pipeline
from transformers.utils import is_flash_attn_2_available
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# --- Configuration ---
MODEL_NAME = "openai/whisper-large-v3"
DEVICE = "cuda:0" if torch.cuda.is_available() else "cpu"
TORCH_DTYPE = torch.float16 if torch.cuda.is_available() else torch.float32 # Use float16
BATCH_SIZE = 8
CHUNK_LENGTH_S = 30
# Enable Flash Attention 2 if available and on CUDA
USE_FLASH_ATTENTION_2 = is_flash_attn_2_available() and DEVICE.startswith("cuda")

logger.info(f"Device: {DEVICE}")
logger.info(f"Torch dtype: {TORCH_DTYPE}")
logger.info(f"Using Flash Attention 2: {USE_FLASH_ATTENTION_2}") # Log flash-attn status
logger.info(f"Batch size: {BATCH_SIZE}")
logger.info(f"Chunk length (s): {CHUNK_LENGTH_S}")


# --- Initialize FastAPI App ---
app = FastAPI()

# --- Load Model ---
pipe = None
try:
    logger.info(f"Loading model: {MODEL_NAME}...")
    # Conditional attention implementation
    model_kwargs = {}
    if USE_FLASH_ATTENTION_2:
        logger.info("Setting attn_implementation to flash_attention_2")
        model_kwargs["attn_implementation"] = "flash_attention_2"
    else:
        logger.info("Setting attn_implementation to sdpa")
        model_kwargs["attn_implementation"] = "sdpa"

    pipe = pipeline(
        "automatic-speech-recognition",
        model=MODEL_NAME,
        torch_dtype=TORCH_DTYPE,
        device=DEVICE,
        model_kwargs=model_kwargs,
    )
    logger.info("Model loaded successfully.")
except Exception as e:
    logger.error(f"Failed to load the model: {e}", exc_info=True)
    # You might want to prevent the app from starting if the model fails to load
    # Or handle requests differently if pipe is None

# --- API Endpoints ---
@app.get("/")
def read_root():
    return {"message": "Insanely Fast Whisper API is running!"}

@app.post("/transcribe")
async def transcribe_audio(file: UploadFile = File(...)):
    """
    Transcribes the uploaded audio file.
    """
    if pipe is None:
        raise HTTPException(status_code=503, detail="Model is not available.")

    if not file:
        raise HTTPException(status_code=400, detail="No file uploaded.")

    logger.info(f"Received file: {file.filename}, content type: {file.content_type}")

    # Create a temporary directory to store the uploaded file
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_file_path = os.path.join(temp_dir, file.filename)

        # Save the uploaded file temporarily
        try:
            with open(temp_file_path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)
            logger.info(f"File saved temporarily to: {temp_file_path}")
        except Exception as e:
            logger.error(f"Failed to save uploaded file: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail="Failed to save uploaded file.")
        finally:
            await file.close() # Ensure the file stream is closed

        # Perform transcription
        try:
            logger.info("Starting transcription...")
            outputs = pipe(
                temp_file_path,
                chunk_length_s=CHUNK_LENGTH_S,
                batch_size=BATCH_SIZE,
                return_timestamps=True, # or "word"
                generate_kwargs={"language": "korean"} # Specify language if known
            )
            logger.info("Transcription finished.")
            logger.debug(f"Transcription output: {outputs}") # Log output for debugging
            return outputs
        except Exception as e:
            logger.error(f"Transcription failed: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")
        # Temporary directory and file are automatically cleaned up when exiting the 'with' block


if __name__ == "__main__":
    import uvicorn
    # This part is for local development/debugging without Docker
    uvicorn.run(app, host="0.0.0.0", port=8000) 