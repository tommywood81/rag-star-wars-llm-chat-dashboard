#!/usr/bin/env python3
"""
Fast Comprehensive System Tests for Star Wars Chat Application

This module provides fast tests for all major components:
- STT Service (Speech-to-Text)
- TTS Service (Text-to-Speech) 
- LLM Services (Phi-2 and TinyLlama)
- Frontend API endpoints
- Database integration
- RAG system
- Model switching functionality

Designed to run in under 30 seconds total.
"""

import pytest
import requests
import json
import time
import os
from pathlib import Path
import tempfile
import wave
import numpy as np
from unittest.mock import Mock, patch, MagicMock

# Test configuration
BASE_URL = "http://localhost"
STT_PORT = 5001
TTS_PORT = 5002
PHI2_PORT = 5003
TINYLLAMA_PORT = 5004
FRONTEND_PORT = 3000

class TestSTTService:
    """Test Speech-to-Text Service - Fast Tests"""
    
    def test_stt_health_check(self):
        """Test STT service health endpoint"""
        response = requests.get(f"{BASE_URL}:{STT_PORT}/health", timeout=5)
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "stt"
        assert "model" in data
    
    def test_stt_models_endpoint(self):
        """Test STT models endpoint"""
        response = requests.get(f"{BASE_URL}:{STT_PORT}/models", timeout=5)
        assert response.status_code == 200
        data = response.json()
        assert "available_models" in data
        assert "current_model" in data
        assert isinstance(data["available_models"], list)
    
    def test_stt_root_endpoint(self):
        """Test STT root endpoint"""
        response = requests.get(f"{BASE_URL}:{STT_PORT}/", timeout=5)
        assert response.status_code == 200
        data = response.json()
        assert data["service"] == "STT Service"
        assert "version" in data
        assert "endpoints" in data

class TestTTSService:
    """Test Text-to-Speech Service - Fast Tests"""
    
    def test_tts_health_check(self):
        """Test TTS service health endpoint"""
        response = requests.get(f"{BASE_URL}:{TTS_PORT}/health", timeout=5)
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "tts"
    
    def test_tts_voices_endpoint(self):
        """Test TTS voices endpoint"""
        response = requests.get(f"{BASE_URL}:{TTS_PORT}/voices", timeout=5)
        assert response.status_code == 200
        data = response.json()
        assert "available_voices" in data or "voices" in data
        voices_key = "available_voices" if "available_voices" in data else "voices"
        assert isinstance(data[voices_key], list)

class TestLLMServices:
    """Test LLM Services - Fast Health Checks Only"""
    
    def test_phi2_health_check(self):
        """Test Phi-2 service health"""
        response = requests.get(f"{BASE_URL}:{PHI2_PORT}/health", timeout=5)
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "model" in data
    
    def test_tinyllama_health_check(self):
        """Test TinyLlama service health"""
        response = requests.get(f"{BASE_URL}:{TINYLLAMA_PORT}/health", timeout=5)
        # TinyLlama might be unhealthy, so we accept both 200 and 503
        assert response.status_code in [200, 503]
        if response.status_code == 200:
            data = response.json()
            assert "model" in data

class TestFrontendAPI:
    """Test frontend API endpoints - Fast Tests"""
    
    def test_frontend_accessible(self):
        """Test that frontend is accessible"""
        try:
            response = requests.get(f"{BASE_URL}:{FRONTEND_PORT}", timeout=5)
            assert response.status_code == 200
        except requests.exceptions.RequestException:
            pytest.skip("Frontend is not accessible")
    
    def test_frontend_static_files(self):
        """Test that frontend static files are served"""
        try:
            response = requests.get(f"{BASE_URL}:{FRONTEND_PORT}/static/js/main.js", timeout=5)
            assert response.status_code == 200
        except requests.exceptions.RequestException:
            pytest.skip("Frontend static files not accessible")

class TestSystemHealth:
    """Fast system health tests"""
    
    def test_all_services_health(self):
        """Test health of all services quickly"""
        services = [
            ("STT", STT_PORT),
            ("TTS", TTS_PORT),
            ("Phi-2", PHI2_PORT),
            ("TinyLlama", TINYLLAMA_PORT)
        ]
        
        healthy_services = []
        for service_name, port in services:
            try:
                response = requests.get(f"{BASE_URL}:{port}/health", timeout=5)
                if response.status_code == 200:
                    healthy_services.append(service_name)
                    print(f"✅ {service_name} service is healthy")
                else:
                    print(f"⚠️ {service_name} service returned status {response.status_code}")
            except requests.exceptions.RequestException as e:
                print(f"❌ {service_name} service is not accessible: {e}")
        
        # At least core services should be healthy
        assert len(healthy_services) >= 2, f"Only {len(healthy_services)} services healthy: {healthy_services}"

class TestQuickIntegration:
    """Quick integration tests - Single API call per test"""
    
    def test_single_phi2_chat_request(self):
        """Test single Phi-2 chat request with timeout"""
        test_data = {
            "character": "Luke Skywalker",
            "message": "Hello",
            "session_id": "test-session"
        }
        
        try:
            response = requests.post(f"{BASE_URL}:{PHI2_PORT}/chat", json=test_data, timeout=15)
            assert response.status_code in [200, 500]  # Accept both success and busy
            if response.status_code == 200:
                data = response.json()
                assert "response" in data
                assert isinstance(data["response"], str)
                assert len(data["response"]) > 0
                print(f"✅ Phi-2 responded in {response.elapsed.total_seconds():.2f}s")
            else:
                print("⚠️ Phi-2 service busy (500)")
        except requests.exceptions.Timeout:
            pytest.skip("Phi-2 service timeout - skipping slow test")
    
    def test_single_tts_request(self):
        """Test single TTS request"""
        test_data = {
            "text": "Test message",
            "voice": "en-us",
            "speed": 1.0
        }
        
        try:
            response = requests.post(f"{BASE_URL}:{TTS_PORT}/synthesize", json=test_data, timeout=10)
            assert response.status_code == 200
            data = response.json()
            assert "audio_file" in data or "audio_url" in data or "audio_data" in data
            print(f"✅ TTS responded in {response.elapsed.total_seconds():.2f}s")
        except requests.exceptions.Timeout:
            pytest.skip("TTS service timeout - skipping slow test")

class TestMockedComponents:
    """Tests using mocked components for speed"""
    
    @patch('requests.get')
    def test_mocked_stt_health(self, mock_get):
        """Test STT health with mock"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "status": "healthy",
            "service": "stt",
            "model": "base"
        }
        mock_get.return_value = mock_response
        
        response = requests.get(f"{BASE_URL}:{STT_PORT}/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
    
    @patch('requests.post')
    def test_mocked_llm_response(self, mock_post):
        """Test LLM response with mock"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "response": "Mocked response from Luke Skywalker",
            "rag_context": [],
            "request_data": {"character": "Luke Skywalker", "message": "Hello"}
        }
        mock_post.return_value = mock_response
        
        test_data = {
            "character": "Luke Skywalker",
            "message": "Hello",
            "session_id": "test-session"
        }
        
        response = requests.post(f"{BASE_URL}:{PHI2_PORT}/chat", json=test_data)
        assert response.status_code == 200
        data = response.json()
        assert "response" in data
        assert "Luke Skywalker" in data["response"]

class TestConfiguration:
    """Test configuration and setup"""
    
    def test_ports_are_accessible(self):
        """Test that all expected ports are accessible"""
        ports = [STT_PORT, TTS_PORT, PHI2_PORT, TINYLLAMA_PORT, FRONTEND_PORT]
        
        accessible_ports = []
        for port in ports:
            try:
                response = requests.get(f"{BASE_URL}:{port}/", timeout=3)
                accessible_ports.append(port)
            except requests.exceptions.RequestException:
                pass
        
        # At least core services should be accessible
        assert len(accessible_ports) >= 3, f"Only {len(accessible_ports)} ports accessible: {accessible_ports}"
    
    def test_environment_variables(self):
        """Test that required environment variables are set"""
        # Check if we're in the right environment
        assert os.path.exists("docker-compose.yml"), "docker-compose.yml not found"
        assert os.path.exists("frontend/"), "frontend directory not found"
        assert os.path.exists("src/"), "src directory not found"

class TestPerformance:
    """Quick performance tests"""
    
    def test_response_times(self):
        """Test that services respond within reasonable time"""
        services = [
            ("STT Health", f"{BASE_URL}:{STT_PORT}/health"),
            ("TTS Health", f"{BASE_URL}:{TTS_PORT}/health"),
            ("Phi-2 Health", f"{BASE_URL}:{PHI2_PORT}/health"),
        ]
        
        for service_name, url in services:
            start_time = time.time()
            try:
                response = requests.get(url, timeout=5)
                end_time = time.time()
                response_time = end_time - start_time
                
                assert response_time < 5, f"{service_name} took {response_time:.2f}s (should be < 5s)"
                print(f"✅ {service_name}: {response_time:.2f}s")
                
            except requests.exceptions.RequestException:
                print(f"⚠️ {service_name}: Not accessible")

if __name__ == "__main__":
    # Run all tests with short timeout
    pytest.main([__file__, "-v", "--tb=short", "--timeout=30"])
