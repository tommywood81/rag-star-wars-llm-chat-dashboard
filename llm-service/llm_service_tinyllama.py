"""
LLM Service for Star Wars Chat App with RAG (Retrieval-Augmented Generation) - TinyLlama Version.

This module provides FastAPI endpoints for character chat using PostgreSQL + pgvector
for retrieving relevant Star Wars dialogue context, specifically configured for TinyLlama.
"""

import os
import logging
import time
import json
import asyncio
from pathlib import Path
from typing import Optional, Dict, Any, List
import numpy as np

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from model_factory import ModelFactory, TinyLlamaModel

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Star Wars Chat - LLM Service (TinyLlama)",
    description="LLM service for Star Wars character chat with RAG using TinyLlama",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ChatRequest(BaseModel):
    """Request model for character chat."""
    message: str
    character: str
    context: Optional[str] = None
    max_tokens: Optional[int] = 200
    temperature: Optional[float] = 0.7
    model: Optional[str] = None  # Allow specifying model

class ChatResponse(BaseModel):
    """Response model for character chat."""
    response: str
    character: str
    rag_context: Optional[List[Dict[str, Any]]] = None
    complete_prompt: Optional[str] = None
    request_data: Optional[Dict[str, Any]] = None
    metadata: Dict[str, Any]

class CharacterInfo(BaseModel):
    """Model for character information."""
    name: str
    description: str
    personality: str
    speaking_style: str

class RAGLLMService:
    """LLM service with RAG capabilities using PostgreSQL + pgvector."""
    
    def __init__(self):
        """Initialize the RAG LLM service."""
        self.characters = self._load_characters()
        self.model_factory = ModelFactory()
        self.embedding_model = None
        self.db_pool = None
        self._load_embedding_model()
        # Database will be initialized on first use
        logger.info("RAG LLM service initialized with TinyLlama")
    
    def _load_characters(self) -> Dict[str, Dict[str, str]]:
        """Load character definitions."""
        characters_file = Path("characters.json")
        
        if not characters_file.exists():
            raise RuntimeError(f"Characters file not found: {characters_file}")
        
        try:
            with open(characters_file, 'r') as f:
                return json.load(f)
        except Exception as e:
            raise RuntimeError(f"Failed to load characters: {e}")
    
    def _load_embedding_model(self):
        """Load the embedding model for generating embeddings."""
        try:
            from transformers import AutoTokenizer, AutoModel
            import torch
            
            logger.info("Loading embedding model")
            model_name = 'sentence-transformers/all-MiniLM-L6-v2'
            self.tokenizer = AutoTokenizer.from_pretrained(model_name)
            self.embedding_model = AutoModel.from_pretrained(model_name)
            logger.info("Embedding model loaded successfully")
            
        except Exception as e:
            raise RuntimeError(f"Failed to load embedding model: {e}")
    
    async def _initialize_database(self):
        """Initialize database connection."""
        try:
            import asyncpg
            
            # Get database connection details from environment
            host = os.getenv("POSTGRES_HOST", "localhost")
            port = int(os.getenv("POSTGRES_PORT", "5432"))
            database = os.getenv("POSTGRES_DB", "star_wars_rag")
            user = os.getenv("POSTGRES_USER", "postgres")
            password = os.getenv("POSTGRES_PASSWORD", "password")
            
            connection_string = f"postgresql://{user}:{password}@{host}:{port}/{database}"
            
            self.db_pool = await asyncpg.create_pool(
                connection_string,
                min_size=2,
                max_size=10,
                command_timeout=60
            )
            
            logger.info("Database connection pool created")
            
        except Exception as e:
            logger.error(f"Database initialization failed: {e}")
            raise RuntimeError(f"Database initialization failed: {e}")
    
    async def _get_relevant_context(self, message: str, character: str, top_k: int = 3) -> List[Dict[str, Any]]:
        """Retrieve relevant context from the database using vector similarity."""
        if not self.embedding_model:
            return []
        
        # Initialize database if not already done
        if not self.db_pool:
            await self._initialize_database()
        
        try:
            # Generate embedding for the user message
            import torch
            
            # Tokenize and encode
            inputs = self.tokenizer(message, return_tensors="pt", padding=True, truncation=True, max_length=512)
            
            # Generate embeddings
            with torch.no_grad():
                outputs = self.embedding_model(**inputs)
                # Use mean pooling
                attention_mask = inputs['attention_mask']
                embeddings = outputs.last_hidden_state * attention_mask.unsqueeze(-1)
                embeddings = embeddings.sum(dim=1) / attention_mask.sum(dim=1, keepdim=True)
                message_embedding = embeddings[0].numpy()
            
            # Query database for similar dialogue
            async with self.db_pool.acquire() as conn:
                # Convert embedding to PostgreSQL format
                embedding_str = ','.join(map(str, message_embedding))
                
                query = """
                SELECT dialogue, character_name, movie, similarity(embedding, '[%s]'::vector) as sim
                FROM star_wars_dialogue 
                WHERE character_name ILIKE $1
                ORDER BY embedding <-> '[%s]'::vector
                LIMIT $2
                """ % (embedding_str, embedding_str)
                
                rows = await conn.fetch(query, f"%{character}%", top_k)
                
                context = []
                for row in rows:
                    context.append({
                        "dialogue": row['dialogue'],
                        "character": row['character_name'],
                        "movie": row['movie'],
                        "similarity": float(row['sim'])
                    })
                
                return context
                
        except Exception as e:
            logger.error(f"Failed to get relevant context: {e}")
            return []
    
    def _create_character_prompt(self, character: str, context: List[Dict[str, Any]], user_message: str) -> str:
        """Create a prompt for the character based on context and user message."""
        if character not in self.characters:
            raise ValueError(f"Unknown character: {character}")
        
        char_info = self.characters[character]
        
        # Build context string
        context_str = ""
        if context:
            context_str = "\n\nRelevant dialogue from Star Wars:\n"
            for i, ctx in enumerate(context, 1):
                context_str += f"{i}. {ctx['character']}: \"{ctx['dialogue']}\" (from {ctx['movie']})\n"
        
        # Create the prompt
        prompt = f"""You are {character} from Star Wars. 

{char_info['description']}

Personality: {char_info['personality']}
Speaking style: {char_info['speaking_style']}

{context_str}

User: {user_message}

{character}:"""
        
        return prompt
    
    async def chat_with_character(self, message: str, character: str, max_tokens: int = 200, temperature: float = 0.7) -> Dict[str, Any]:
        """Chat with a Star Wars character using RAG."""
        try:
            # Get relevant context
            context = await self._get_relevant_context(message, character)
            
            # Create character prompt
            prompt = self._create_character_prompt(character, context, message)
            
            # Generate response using TinyLlama
            try:
                response = self.model_factory.generate_response(
                    prompt, 
                    max_tokens=max_tokens, 
                    temperature=temperature,
                    model_name="tinyllama"
                )
            except Exception as e:
                logger.error(f"Model generation failed: {e}")
                response = f"I apologize, but I'm having trouble responding right now. Please try again."
            
            return {
                "response": response,
                "character": character,
                "rag_context": context,
                "complete_prompt": prompt,
                "request_data": {
                    "message": message,
                    "max_tokens": max_tokens,
                    "temperature": temperature
                },
                "metadata": {
                    "model": "TinyLlama-1.1B",
                    "context_retrieved": len(context),
                    "timestamp": time.time()
                }
            }
            
        except Exception as e:
            logger.error(f"Chat failed: {e}")
            raise HTTPException(status_code=500, detail=f"Chat failed: {str(e)}")

# Initialize the service
rag_service = RAGLLMService()

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    try:
        # Check if model is loaded
        model_info = rag_service.model_factory.get_current_model_info()
        
        # Check database connection
        db_status = "disconnected"
        try:
            if rag_service.db_pool:
                async with rag_service.db_pool.acquire() as conn:
                    await conn.fetchval("SELECT 1")
                db_status = "connected"
        except:
            pass
        
        return {
            "status": "healthy",
            "service": "llm",
            "model": model_info.get("name", "unknown"),
            "model_path": model_info.get("model_path", "unknown"),
            "database": db_status,
            "characters": list(rag_service.characters.keys()),
            "available_models": list(rag_service.model_factory.get_available_models().keys())
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Health check failed: {str(e)}")

@app.post("/chat", response_model=ChatResponse)
async def chat_endpoint(request: ChatRequest):
    """Chat with a Star Wars character."""
    return await rag_service.chat_with_character(
        request.message,
        request.character,
        request.max_tokens,
        request.temperature
    )

@app.get("/characters")
async def get_characters():
    """Get available characters."""
    return {
        "characters": [
            {
                "name": name,
                "description": info["description"],
                "personality": info["personality"],
                "speaking_style": info["speaking_style"]
            }
            for name, info in rag_service.characters.items()
        ]
    }

@app.get("/models")
async def get_models():
    """Get available models."""
    return rag_service.model_factory.get_available_models()

@app.get("/model/current")
async def get_current_model():
    """Get current model information."""
    return rag_service.model_factory.get_current_model_info()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5003)
