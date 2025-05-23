   # test_model_load.py
   import torch
   from transformers import AutoModelForCausalLM, AutoTokenizer
   import logging

   logging.basicConfig(level=logging.INFO)
   logger = logging.getLogger(__name__)

   MODEL_ID = "Qwen/Qwen2.5-0.5B-Instruct"

   def load_model():
       logger.info(f"Attempting to load model: {MODEL_ID}")
       try:
           tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
           logger.info("Tokenizer loaded.")
           if torch.cuda.is_available():
               model = AutoModelForCausalLM.from_pretrained(MODEL_ID, torch_dtype=torch.float16).to("cuda")
               logger.info("Model loaded on CUDA with float16.")
           else:
               model = AutoModelForCausalLM.from_pretrained(MODEL_ID)
               logger.info("Model loaded on CPU.")
           
           if tokenizer.pad_token_id is None:
               tokenizer.pad_token_id = tokenizer.eos_token_id
               logger.info(f"tokenizer.pad_token_id set to tokenizer.eos_token_id: {tokenizer.eos_token_id}")
           
           logger.info("Model and tokenizer loaded successfully.")
           return model, tokenizer
       except Exception as e:
           logger.error(f"Error loading model or tokenizer: {e}", exc_info=True)
           return None, None

   if __name__ == "__main__":
       model, tokenizer = load_model()
       if model and tokenizer:
           logger.info("Test script finished: Model ready.")
       else:
           logger.info("Test script finished: Model loading failed.")