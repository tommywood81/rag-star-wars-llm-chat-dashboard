"""
Model Factory for Star Wars Chat App - LLM Service

This module implements a factory pattern to support multiple LLM models
with a unified interface for easy switching and extension.
"""

import os
import logging
from abc import ABC, abstractmethod
from pathlib import Path
from typing import Dict, Any, Optional
import llama_cpp

logger = logging.getLogger(__name__)

class BaseLLMModel(ABC):
    """Abstract base class for LLM models."""
    
    @abstractmethod
    def generate(self, prompt: str, max_tokens: int = 200, temperature: float = 0.7) -> str:
        """Generate text response from prompt."""
        pass
    
    @abstractmethod
    def get_model_info(self) -> Dict[str, Any]:
        """Get model information."""
        pass
    
    @abstractmethod
    def is_loaded(self) -> bool:
        """Check if model is loaded."""
        pass

class Phi2Model(BaseLLMModel):
    """Phi-2 model implementation."""
    
    def __init__(self):
        self.model = None
        self.model_path = None
        self._load_model()
    
    def _load_model(self):
        """Load the Phi-2 model."""
        try:
            # Try multiple possible model paths
            possible_paths = [
                Path("models/phi-2.Q4_K_M.gguf"),
                Path("/app/models/phi-2.Q4_K_M.gguf"),
                Path("../models/phi-2.Q4_K_M.gguf"),
                Path("llm-service/models/phi-2.Q4_K_M.gguf")
            ]
            
            model_path = None
            for path in possible_paths:
                if path.exists():
                    model_path = path
                    break
            
            if not model_path:
                raise RuntimeError(f"Phi-2 model not found. Tried paths: {[str(p) for p in possible_paths]}")
            
            logger.info(f"Loading Phi-2 model from {model_path}")
            
            self.model = llama_cpp.Llama(
                model_path=str(model_path),
                n_ctx=1024,
                n_threads=4,
                n_batch=512,
                n_gpu_layers=0,
                verbose=False
            )
            
            self.model_path = str(model_path)
            logger.info("Phi-2 model loaded successfully")
            
        except Exception as e:
            logger.error(f"Failed to load Phi-2 model: {e}")
            raise RuntimeError(f"Failed to load Phi-2 model: {e}")
    
    def generate(self, prompt: str, max_tokens: int = 200, temperature: float = 0.7) -> str:
        """Generate text response using Phi-2."""
        if not self.model:
            raise RuntimeError("Phi-2 model not loaded")
        
        try:
            response = self.model(
                prompt,
                max_tokens=max_tokens,
                temperature=temperature,
                stop=["User:", "\n\n", "###"],
                echo=False
            )
            
            generated_text = response['choices'][0]['text'].strip()
            return generated_text
            
        except Exception as e:
            raise RuntimeError(f"Phi-2 generation failed: {e}")
    
    def get_model_info(self) -> Dict[str, Any]:
        """Get Phi-2 model information."""
        return {
            "name": "Phi-2",
            "type": "local",
            "model_path": self.model_path,
            "context_length": 1024,
            "threads": 4,
            "batch_size": 512,
            "description": "Microsoft's Phi-2 model - good quality, moderate speed"
        }
    
    def is_loaded(self) -> bool:
        """Check if Phi-2 model is loaded."""
        return self.model is not None

class TinyLlamaModel(BaseLLMModel):
    """TinyLlama-1.1B model implementation."""
    
    def __init__(self):
        self.model = None
        self.model_path = None
        self._load_model()
    
    def _load_model(self):
        """Load the TinyLlama-1.1B model."""
        try:
            # Try multiple possible model paths
            possible_paths = [
                Path("models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"),
                Path("/app/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"),
                Path("../models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"),
                Path("llm-service/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf")
            ]
            
            model_path = None
            for path in possible_paths:
                if path.exists():
                    model_path = path
                    break
            
            if not model_path:
                raise RuntimeError(f"TinyLlama model not found. Tried paths: {[str(p) for p in possible_paths]}")
            
            logger.info(f"Loading TinyLlama-1.1B model from {model_path}")
            
            self.model = llama_cpp.Llama(
                model_path=str(model_path),
                n_ctx=2048,
                n_threads=4,
                n_batch=512,
                n_gpu_layers=0,
                verbose=False
            )
            
            self.model_path = str(model_path)
            logger.info("TinyLlama-1.1B model loaded successfully")
            
        except Exception as e:
            logger.error(f"Failed to load TinyLlama model: {e}")
            raise RuntimeError(f"Failed to load TinyLlama model: {e}")
    
    def generate(self, prompt: str, max_tokens: int = 200, temperature: float = 0.7) -> str:
        """Generate text response using TinyLlama."""
        if not self.model:
            raise RuntimeError("TinyLlama model not loaded")
        
        try:
            # TinyLlama uses a different prompt format
            formatted_prompt = f"<|system|>\nYou are a helpful AI assistant.\n<|user|>\n{prompt}\n<|assistant|>\n"
            
            response = self.model(
                formatted_prompt,
                max_tokens=max_tokens,
                temperature=temperature,
                stop=["<|user|>", "<|system|>", "\n\n"],
                echo=False
            )
            
            generated_text = response['choices'][0]['text'].strip()
            return generated_text
            
        except Exception as e:
            raise RuntimeError(f"TinyLlama generation failed: {e}")
    
    def get_model_info(self) -> Dict[str, Any]:
        """Get TinyLlama model information."""
        return {
            "name": "TinyLlama-1.1B",
            "type": "local",
            "model_path": self.model_path,
            "context_length": 2048,
            "threads": 4,
            "batch_size": 512,
            "description": "TinyLlama-1.1B - fast responses, smaller model"
        }
    
    def is_loaded(self) -> bool:
        """Check if TinyLlama model is loaded."""
        return self.model is not None

class ModelFactory:
    """Factory class for creating and managing LLM models."""
    
    def __init__(self):
        self.models: Dict[str, BaseLLMModel] = {}
        self.current_model: Optional[str] = None
        self._initialize_models()
    
    def _initialize_models(self):
        """Initialize available models."""
        try:
            # Try to load Phi-2
            try:
                self.models["phi-2"] = Phi2Model()
                self.current_model = "phi-2"
                logger.info("Phi-2 model initialized successfully")
            except Exception as e:
                logger.warning(f"Failed to initialize Phi-2: {e}")
            
            # Try to load TinyLlama
            try:
                self.models["tinyllama"] = TinyLlamaModel()
                if not self.current_model:
                    self.current_model = "tinyllama"
                logger.info("TinyLlama model initialized successfully")
            except Exception as e:
                logger.warning(f"Failed to initialize TinyLlama: {e}")
            
            if not self.current_model:
                raise RuntimeError("No models could be loaded")
                
        except Exception as e:
            logger.error(f"Model factory initialization failed: {e}")
            raise
    
    def get_model(self, model_name: str = None) -> BaseLLMModel:
        """Get a specific model or the current default model."""
        if model_name:
            if model_name not in self.models:
                raise ValueError(f"Model '{model_name}' not available. Available: {list(self.models.keys())}")
            return self.models[model_name]
        
        if not self.current_model:
            raise RuntimeError("No current model set")
        
        return self.models[self.current_model]
    
    def set_current_model(self, model_name: str):
        """Set the current default model."""
        if model_name not in self.models:
            raise ValueError(f"Model '{model_name}' not available. Available: {list(self.models.keys())}")
        
        self.current_model = model_name
        logger.info(f"Current model set to: {model_name}")
    
    def get_available_models(self) -> Dict[str, Dict[str, Any]]:
        """Get information about all available models."""
        return {
            name: model.get_model_info() 
            for name, model in self.models.items()
        }
    
    def get_current_model_info(self) -> Dict[str, Any]:
        """Get information about the current model."""
        if not self.current_model:
            return {"error": "No current model set"}
        
        info = self.models[self.current_model].get_model_info()
        info["is_current"] = True
        return info
    
    def generate_response(self, prompt: str, max_tokens: int = 200, temperature: float = 0.7, model_name: str = None) -> str:
        """Generate response using specified or current model."""
        model = self.get_model(model_name)
        return model.generate(prompt, max_tokens, temperature)
