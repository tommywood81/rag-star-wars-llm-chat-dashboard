# Star Wars RAG Chat Application

A production-ready Retrieval-Augmented Generation (RAG) system that brings Star Wars characters to life through AI-powered conversations using authentic dialogue from the original movie scripts.

## Overview

This project demonstrates advanced NLP techniques by creating an intelligent chat system that allows users to converse with iconic Star Wars characters like Luke Skywalker, Darth Vader, and Han Solo. The system uses Retrieval-Augmented Generation (RAG) to provide contextually relevant responses by retrieving and incorporating actual dialogue from the original Star Wars trilogy scripts.

### Key Achievements

- 2,267 dialogue lines processed from Star Wars scripts with semantic embeddings
- Real-time similarity search using pgvector and PostgreSQL
- Multi-model support with TinyLlama (1.1B) and Phi-2 (2.7B) parameters
- Production deployment on DigitalOcean with Docker containerization
- Full-stack application with React frontend and FastAPI backend services
- Advanced RAG pipeline with explainability features and similarity scoring

### Technical Highlights

- Semantic Search: Uses sentence-transformers (all-MiniLM-L6-v2) for 384-dimensional embeddings
- Vector Database: PostgreSQL with pgvector extension for efficient similarity queries
- Microservices Architecture: Separate services for LLM, STT, TTS, and API
- Real-time Processing: Live speech-to-text and text-to-speech capabilities
- Character Context: Retrieves the 3 most relevant movie lines for each conversation

## Features

### Character Chat System
- Authentic Responses: Characters respond using their actual movie dialogue
- Context-Aware: Retrieves relevant dialogue based on conversation context
- Multi-Character Support: Chat with Luke Skywalker, Darth Vader, Han Solo, and more
- Personality Preservation: Maintains character-specific speaking styles and traits

### Advanced RAG Implementation
- Semantic Retrieval: Finds contextually relevant dialogue using vector similarity
- Explainability: Shows which movie lines influenced each response
- Similarity Scoring: Displays confidence scores for retrieved context
- Character Filtering: Retrieves dialogue specific to the selected character

### Multi-Modal Interface
- Voice Input: Speech-to-text for natural conversation
- Voice Output: Text-to-speech for character responses
- Visual Dashboard: Real-time display of retrieved movie context
- Model Selection: Choose between TinyLlama (fast) and Phi-2 (detailed) models

### Production Architecture
- Docker Containerization: Fully containerized microservices
- Database Integration: PostgreSQL with pgvector for vector operations
- API-First Design: RESTful APIs for all services
- Scalable Deployment: Ready for cloud deployment and scaling

## Live Demo

Experience the full system with:
- Real-time character conversations
- Voice input/output capabilities
- Live RAG context display
- Model comparison (TinyLlama vs Phi-2)

## Architecture

The system follows a microservices architecture with the following components:

- **React Frontend**: User interface for chat interactions
- **API Gateway**: Central service orchestrating all backend operations
- **LLM Services**: Two separate services for different language models
- **STT Service**: Speech-to-text processing using Whisper
- **TTS Service**: Text-to-speech synthesis using gTTS
- **PostgreSQL Database**: Vector database with pgvector extension

The RAG pipeline works by:
1. Processing user queries through embedding generation
2. Performing vector similarity search against the dialogue database
3. Retrieving the most relevant context lines
4. Generating responses using the retrieved context

## System Performance

### Data Processing Results
- Total Dialogue Lines: 2,267 processed and embedded
- Characters: 109 unique characters identified
- Movies: Complete original trilogy (A New Hope, Empire Strikes Back, Return of the Jedi)
- Top Characters by Line Count:
  - Han Solo: 399 lines
  - Luke Skywalker: 394 lines
  - C-3PO: 248 lines
  - Princess Leia: 222 lines
  - Darth Vader: 120 lines

### Performance Metrics
- Embedding Model: all-MiniLM-L6-v2 (384 dimensions)
- Retrieval Speed: Sub-second similarity search
- Context Quality: 0.4-0.6 similarity scores for relevant dialogue
- Model Performance: 
  - TinyLlama: ~2-3 second response time
  - Phi-2: ~10-15 second response time

## Technology Stack

### Backend Services
- FastAPI: High-performance API framework
- PostgreSQL + pgvector: Vector database for similarity search
- sentence-transformers: Semantic embedding generation
- TinyLlama/Phi-2: Local LLM inference
- Whisper: Speech-to-text processing
- gTTS: Text-to-speech synthesis

### Frontend
- React: Modern UI framework
- Bootstrap: Responsive design system
- Axios: HTTP client for API communication

### Infrastructure
- Docker: Containerization and orchestration
- DigitalOcean: Cloud deployment platform
- Docker Compose: Multi-service orchestration

### Production Deployment
In production, the application is deployed on DigitalOcean with the same port configuration:
- Live Demo: http://209.38.89.159:3000
- All services are accessible via the droplet's public IP address

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Python 3.11+
- Node.js 18+

### Local Development

```bash
# Clone the repository
git clone https://github.com/yourusername/star-wars-chat-app.git
cd star-wars-chat-app

# Start all services
docker-compose up -d

# Access the application
open http://localhost:3000
```

### Production Deployment

```bash
# Deploy to DigitalOcean
docker-compose -f docker-compose.production.yml up -d

# Verify services
docker ps
```

## Project Structure

```
star-wars-chat-app/
├── frontend/                 # React frontend application
│   ├── src/App.js           # Main application component
│   └── Dockerfile           # Frontend containerization
├── llm-service/             # LLM inference service
│   ├── llm_service_standalone.py    # Phi-2 service
│   ├── llm_service_tinyllama.py     # TinyLlama service
│   └── model_factory.py     # Model management
├── stt-service/             # Speech-to-text service
├── tts-service/             # Text-to-speech service
├── src/star_wars_rag/       # Core RAG implementation
│   ├── embeddings.py        # Embedding generation
│   ├── retrieval.py         # Vector similarity search
│   └── database.py          # Database operations
├── data/                    # Star Wars script data
│   ├── raw/                 # Original script files
│   └── processed/           # Processed dialogue data
├── tests/                   # Comprehensive test suite
├── docker-compose.yml       # Development orchestration
└── docker-compose.production.yml  # Production deployment
```

## Testing

```bash
# Run all tests
python -m pytest tests/ -v

# Run specific test categories
python -m pytest tests/ -k "not integration" -v  # Unit tests
python -m pytest tests/ -m integration -v         # Integration tests

# Test RAG functionality
python -m pytest tests/test_retrieval.py -v
```

## Usage Examples

### Basic Character Chat

```python
# Initialize the RAG system
from star_wars_rag import StarWarsRAGApp

app = StarWarsRAGApp()
app.load_from_scripts("data/raw/")

# Chat with Luke Skywalker
response = app.chat_with_character(
    "Tell me about the Force", 
    "Luke Skywalker"
)

print(f"{response['character']}: {response['response']}")
print(f"Context: {response['rag_context']}")
```

### API Usage

```bash
# Chat with a character via API
curl -X POST http://localhost:5003/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello Luke, how are you?",
    "character": "Luke Skywalker"
  }'
```

## RAG Implementation Details

### Embedding Generation
- Model: sentence-transformers/all-MiniLM-L6-v2
- Dimensions: 384
- Context: Character + Movie + Scene + Dialogue
- Processing: Batch processing for efficiency

### Similarity Search
- Algorithm: Cosine similarity using pgvector
- Index: IVFFlat index for fast retrieval
- Threshold: Top 3 most similar dialogue lines
- Filtering: Character-specific context retrieval

### Response Generation
- Context Injection: Retrieved dialogue included in prompt
- Character Consistency: Personality and speaking style preserved
- Explainability: Shows which movie lines influenced response

## Future Enhancements

### Planned Features
- Extended Universe: Include prequels, sequels, and spin-offs
- Character Relationships: Context-aware responses based on character interactions
- Scene Context: Include scene descriptions for richer context
- Multi-language Support: Support for different languages and dubs

### Technical Improvements
- Vector Database Migration: Move to specialized vector databases (Pinecone, Weaviate)
- Model Fine-tuning: Fine-tune models on Star Wars dialogue
- Caching Layer: Implement Redis for response caching
- Monitoring: Add comprehensive logging and metrics

## Performance Optimization

### Database Optimization
- Indexing: Optimized vector indexes for fast similarity search
- Connection Pooling: Efficient database connection management
- Query Optimization: Optimized SQL queries for vector operations

### Model Optimization
- Quantization: Model quantization for faster inference
- Batch Processing: Efficient batch processing for embeddings
- Caching: Response caching for common queries

## Contributing

We welcome contributions! Please see our Contributing Guidelines for details.

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Star Wars: For the incredible universe and characters
- OpenAI: For inspiration in RAG system design
- Hugging Face: For the sentence-transformers library
- PostgreSQL: For the pgvector extension

---

Built with passion for Star Wars fans and AI enthusiasts

*May the Force be with your embeddings!*

---

## Contact

- GitHub: @yourusername
- LinkedIn: Your LinkedIn
- Email: your.email@example.com

**Live Demo**: http://209.38.89.159:3000
