import React, { useState, useEffect, useRef } from 'react';
import axios from 'axios';
import './App.css';

function App() {
  const [isRecording, setIsRecording] = useState(false);
  const [selectedCharacter, setSelectedCharacter] = useState('Luke Skywalker');
  const [messages, setMessages] = useState([]);
  const [isProcessing, setIsProcessing] = useState(false);
  const [isMuted, setIsMuted] = useState(false);
  const [connectionStatus, setConnectionStatus] = useState('checking');
  const [performanceMetrics, setPerformanceMetrics] = useState({});
  const [systemPrompt, setSystemPrompt] = useState('');
  const [logs, setLogs] = useState([]);
  const [lastRequestData, setLastRequestData] = useState(null);
  const [lastLLMRequest, setLastLLMRequest] = useState(null);
  const [lastLLMResponse, setLastLLMResponse] = useState(null);
  const [ragContext, setRagContext] = useState([]);
  const [buildVersion] = useState('v1.4.0-debug');
  const [liveTranscription, setLiveTranscription] = useState('');
  const [ttsProgress, setTtsProgress] = useState(0);
  const [isTtsPlaying, setIsTtsPlaying] = useState(false);
  const [showExplainability, setShowExplainability] = useState(false);
  const [explainabilityData, setExplainabilityData] = useState(null);
  
  const mediaRecorderRef = useRef(null);
  const audioChunksRef = useRef([]);
  const audioRef = useRef(null);
  const waveformRef = useRef(null);

  const characters = [
    { 
      name: 'Luke Skywalker', 
      emoji: '⚔️',
      color: '#4a90e2',
      voice: 'en-us',
      speed: 1.2,
      personality: 'Optimistic, brave, determined, and committed to doing what\'s right. He believes in the Force and the power of good.',
      speaking_style: 'Speaks with hope and determination. Uses phrases like \'The Force is with us\' and \'I believe in the Force.\''
    },
    { 
      name: 'Darth Vader', 
      emoji: '🖤',
      color: '#e74c3c',
      voice: 'en',
      speed: 0.8,
      personality: 'Intimidating, commanding, conflicted, and powerful. He is both feared and respected.',
      speaking_style: 'Speaks with authority and menace. Uses phrases like \'I find your lack of faith disturbing\' and \'The Force is strong with this one.\''
    },
    { 
      name: 'Yoda', 
      emoji: '🟢',
      color: '#27ae60',
      voice: 'en-gb',
      speed: 0.7,
      personality: 'Wise, patient, philosophical, and deeply connected to the Force. He speaks in a unique, backwards manner.',
      speaking_style: 'Speaks in a distinctive backwards word order. Uses phrases like \'Do or do not, there is no try\' and \'The Force is strong with you.\''
    },
    { 
      name: 'Han Solo', 
      emoji: '🤠',
      color: '#f39c12',
      voice: 'en-au',
      speed: 1.1,
      personality: 'Confident, sarcastic, loyal, and resourceful. He\'s a bit of a rogue but has a heart of gold.',
      speaking_style: 'Speaks with confidence and sarcasm. Uses phrases like \'I know\' and \'Great, kid! Don\'t get cocky.\''
    },
    { 
      name: 'Princess Leia', 
      emoji: '👑',
      color: '#9b59b6',
      voice: 'en-gb',
      speed: 1.0,
      personality: 'Strong-willed, intelligent, courageous, and determined. She\'s a natural leader and diplomat.',
      speaking_style: 'Speaks with authority and intelligence. Uses phrases like \'Help me, Obi-Wan Kenobi\' and \'I love you.\''
    },
    { 
      name: 'Obi-Wan Kenobi', 
      emoji: '🧙‍♂️',
      color: '#3498db',
      voice: 'en-gb',
      speed: 0.9,
      personality: 'Wise, patient, diplomatic, and deeply knowledgeable about the Force and Jedi ways.',
      speaking_style: 'Speaks with wisdom and calm authority. Uses phrases like \'The Force will be with you, always\' and \'These aren\'t the droids you\'re looking for.\''
    }
  ];

  // Check service health on component mount
  useEffect(() => {
    checkServiceHealth();
    const interval = setInterval(checkServiceHealth, 30000); // Check every 30 seconds
    return () => clearInterval(interval);
  }, []);

  // Clear chat when character changes
  useEffect(() => {
    setMessages([]);
    setLastRequestData(null);
    setLastLLMRequest(null);
    setLastLLMResponse(null);
    setRagContext([]);
    setSystemPrompt('');
    setLiveTranscription('');
    setTtsProgress(0);
    setIsTtsPlaying(false);
    setExplainabilityData(null);
    addLog(`Character changed to ${selectedCharacter}`);
  }, [selectedCharacter]);

  const checkServiceHealth = async () => {
    try {
      const services = [
        { name: 'STT', url: `${process.env.REACT_APP_STT_URL || 'http://localhost:5001'}/health` },
        { name: 'TTS', url: `${process.env.REACT_APP_TTS_URL || 'http://localhost:5002'}/health` },
        { name: 'LLM', url: `${process.env.REACT_APP_LLM_URL || 'http://localhost:5003'}/health` }
      ];

      const healthChecks = await Promise.allSettled(
        services.map(service => axios.get(service.url, { timeout: 5000 }))
      );

      const allHealthy = healthChecks.every(result => result.status === 'fulfilled');
      setConnectionStatus(allHealthy ? 'healthy' : 'error');
      
      if (!allHealthy) {
        addLog('⚠️ Some services are not responding');
      }
    } catch (error) {
      setConnectionStatus('error');
      addLog('❌ Health check failed');
    }
  };

  const addLog = (message) => {
    const timestamp = new Date().toLocaleTimeString();
    setLogs(prev => [...prev.slice(-9), `${timestamp}: ${message}`]);
  };

  const startRecording = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      mediaRecorderRef.current = new MediaRecorder(stream);
      audioChunksRef.current = [];

      mediaRecorderRef.current.ondataavailable = (event) => {
        audioChunksRef.current.push(event.data);
      };

      mediaRecorderRef.current.onstop = async () => {
        const audioBlob = new Blob(audioChunksRef.current, { type: 'audio/wav' });
        await processAudio(audioBlob);
      };

      mediaRecorderRef.current.start();
      setIsRecording(true);
      setLiveTranscription('🎤 Recording...');
      addLog('🎤 Recording started');
    } catch (error) {
      console.error('Error starting recording:', error);
      addLog('❌ Failed to start recording');
      alert('Error accessing microphone. Please check permissions.');
    }
  };

  const stopRecording = () => {
    if (mediaRecorderRef.current && isRecording) {
      mediaRecorderRef.current.stop();
      mediaRecorderRef.current.stream.getTracks().forEach(track => track.stop());
      setIsRecording(false);
      setLiveTranscription('');
      addLog('⏹️ Recording stopped');
    }
  };

  const processAudio = async (audioBlob) => {
    const startTime = Date.now();
    setIsProcessing(true);
    addLog('🔄 Processing audio...');
    
    try {
      // Step 1: Send audio to STT service
      const sttStartTime = Date.now();
      const formData = new FormData();
      formData.append('file', audioBlob, 'audio.wav');
      
      const sttResponse = await axios.post(`${process.env.REACT_APP_STT_URL || 'http://localhost:5001'}/transcribe`, formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
      
      const sttLatency = Date.now() - sttStartTime;
      const transcription = sttResponse.data.text;
      addLog(`🎯 STT completed in ${sttLatency}ms: "${transcription}"`);
      
      // Add user message
      const userMessage = { type: 'user', text: transcription, timestamp: new Date() };
      setMessages(prev => [...prev, userMessage]);
      
      // Process with LLM
      await processWithLLM(transcription, startTime, sttLatency);
      
    } catch (error) {
      console.error('Error processing audio:', error);
      addLog('❌ Audio processing failed');
      alert('Error processing your message. Please try again.');
    } finally {
      setIsProcessing(false);
    }
  };

  const processWithLLM = async (text, startTime, sttLatency = 0) => {
    try {
      // Prepare LLM request data
      const llmRequestData = {
        message: text,
        character: selectedCharacter
      };
      
      // Store the exact request being sent to LLM
      setLastLLMRequest({
        url: `${process.env.REACT_APP_LLM_URL || 'http://localhost:5003'}/chat`,
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        payload: llmRequestData,
        timestamp: new Date().toISOString()
      });
      
      // Step 2: Send text to LLM service
      const llmStartTime = Date.now();
      const llmResponse = await axios.post(`${process.env.REACT_APP_LLM_URL || 'http://localhost:5003'}/chat`, llmRequestData);
      const llmLatency = Date.now() - llmStartTime;
      
             // Store the complete LLM response for RAG explainability
       setLastLLMResponse(llmResponse.data);
       setRagContext(llmResponse.data.rag_context || []);
       setSystemPrompt(llmResponse.data.complete_prompt || '');
       
       // Store request data for context panel
       setLastRequestData({
         stt_latency: sttLatency,
         embedding_latency: llmResponse.data.embedding_latency || 0,
         llm_latency: llmLatency,
         tts_latency: 0, // Will be updated after TTS
         total_latency: Date.now() - startTime
       });
      
      // Set explainability data
      setExplainabilityData({
        userMessage: text,
        character: selectedCharacter,
        ragContext: llmResponse.data.rag_context || [],
        systemPrompt: llmResponse.data.complete_prompt || '',
        llmResponse: llmResponse.data.response,
        performance: {
          stt: sttLatency,
          llm: llmLatency,
          total: Date.now() - startTime
        },
        timestamp: new Date().toISOString()
      });
      
      const characterResponse = llmResponse.data.response;
      addLog(`🤖 LLM response in ${llmLatency}ms`);
      
      // Add character response
      const characterMessage = { type: 'character', text: characterResponse, timestamp: new Date() };
      setMessages(prev => [...prev, characterMessage]);
      
      // Step 3: Convert response to speech
      const ttsStartTime = Date.now();
      const characterData = getSelectedCharacterData();
      const ttsResponse = await axios.post(`${process.env.REACT_APP_TTS_URL || 'http://localhost:5002'}/synthesize`, {
        text: characterResponse,
        voice: characterData?.voice || 'en',
        speed: characterData?.speed || 1.0
      });
             const ttsLatency = Date.now() - ttsStartTime;
       addLog(`🔊 TTS generated in ${ttsLatency}ms`);
       
       // Update request data with TTS latency
       setLastRequestData(prev => prev ? {
         ...prev,
         tts_latency: ttsLatency
       } : null);
      
      // Update performance metrics
      const totalLatency = Date.now() - startTime;
      setPerformanceMetrics({
        stt: sttLatency,
        llm: llmLatency,
        tts: ttsLatency,
        total: totalLatency,
        tokensPerSec: characterResponse.length / (llmLatency / 1000)
      });
      
      // Play the audio response (unless muted)
      if (!isMuted) {
        const audioFilename = ttsResponse.data.audio_file.split('/').pop();
        const audioUrl = `${process.env.REACT_APP_TTS_URL || 'http://localhost:5002'}/audio/${audioFilename}`;
        const audio = new Audio(audioUrl);
        audioRef.current = audio;
        
        // Set up audio progress tracking
        audio.addEventListener('timeupdate', () => {
          const progress = (audio.currentTime / audio.duration) * 100;
          setTtsProgress(progress);
        });
        
        audio.addEventListener('play', () => {
          setIsTtsPlaying(true);
        });
        
        audio.addEventListener('ended', () => {
          setIsTtsPlaying(false);
          setTtsProgress(0);
        });
        
        audio.play();
        addLog('🔊 Playing audio response');
      } else {
        addLog('🔇 Audio muted');
      }
      
    } catch (error) {
      console.error('Error processing with LLM:', error);
      addLog('❌ LLM processing failed');
      alert('Error processing your message. Please try again.');
    }
  };

  const sendTextMessage = async () => {
    const textInput = document.getElementById('text-input');
    const text = textInput.value.trim();
    
    if (!text) return;
    
    textInput.value = '';
    
    // Add user message
    const userMessage = { type: 'user', text, timestamp: new Date() };
    setMessages(prev => [...prev, userMessage]);
    
    const startTime = Date.now();
    await processWithLLM(text, startTime);
  };

  const exportConversation = () => {
    const exportData = {
      timestamp: new Date().toISOString(),
      character: selectedCharacter,
      characterData: getSelectedCharacterData(),
      messages: messages,
      debug: {
        lastRequest: lastLLMRequest,
        lastResponse: lastLLMResponse,
        performanceMetrics: performanceMetrics,
        ragContext: ragContext,
        systemPrompt: systemPrompt,
        explainabilityData: explainabilityData
      }
    };
    
    const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `star-wars-chat-${selectedCharacter}-${new Date().toISOString().split('T')[0]}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    addLog('💾 Conversation exported');
  };

  const toggleMute = () => {
    setIsMuted(!isMuted);
    if (audioRef.current) {
      if (isMuted) {
        audioRef.current.play();
      } else {
        audioRef.current.pause();
      }
    }
    addLog(isMuted ? '🔊 Audio unmuted' : '🔇 Audio muted');
  };

  const getSelectedCharacterData = () => {
    return characters.find(char => char.name === selectedCharacter);
  };

  const openExplainability = () => {
    if (explainabilityData) {
      setShowExplainability(true);
    }
  };

  return (
    <div className="app unified-mode">
      {/* Top Bar */}
      <header className="top-bar">
        <div className="top-bar-left">
          <h1 className="app-title">Star Wars LLM Chat – Debug Console</h1>
          <div className={`connection-status ${connectionStatus}`}>
            {connectionStatus === 'healthy' ? '🟢 All Systems Operational' : '🔴 System Error'}
          </div>
        </div>
      </header>

      <div className="main-content">
        {/* Left Column - Movie Lines */}
        <div className="left-panel">
          <div className="panel-header">
            <h3>🎬 Movie Lines Retrieved</h3>
          </div>
          <div className="movie-lines-panel">
                         {ragContext.length > 0 ? (
               ragContext.map((line, index) => (
                 <div key={index} className="movie-line-item">
                   <div className="movie-line-header">
                     <span className="movie-title">{line.movie_title || line.movie || 'Star Wars'}</span>
                     <span className="relevance-score">Score: {line.similarity_score?.toFixed(3) || line.score?.toFixed(3) || 'N/A'}</span>
                   </div>
                   <div className="movie-dialogue">
                     <strong>{line.character}:</strong> {line.dialogue}
                   </div>
                 </div>
               ))
             ) : (
              <div className="empty-state">
                <p>No movie lines retrieved yet. Send a message to see relevant dialogue!</p>
              </div>
            )}
          </div>
        </div>

        {/* Middle Column - Chat */}
        <div className="chat-panel">
          <div className="character-selector">
            <h3>Choose Your Character</h3>
            <div className="character-grid">
                             {characters.map(character => (
                 <div
                   key={character.name}
                   className={`character-card ${selectedCharacter === character.name ? 'selected' : ''}`}
                   onClick={() => setSelectedCharacter(character.name)}
                   style={{ borderColor: character.color }}
                 >
                   <div className="character-emoji">{character.emoji}</div>
                   <h4>{character.name}</h4>
                 </div>
               ))}
            </div>
          </div>

          <div className="messages-container">
            {messages.map((message, index) => (
              <div key={index} className={`message ${message.type}`}>
                                 <div className="message-avatar">
                   {message.type === 'user' ? (
                     <div className="user-avatar">⚔️</div>
                   ) : (
                     <div className="character-avatar-small">🤖</div>
                   )}
                 </div>
                <div className="message-content">
                  <strong>{message.type === 'user' ? 'You' : selectedCharacter}:</strong>
                  <p>{message.text}</p>
                  <small>{message.timestamp.toLocaleTimeString()}</small>
                </div>
              </div>
            ))}
            {isProcessing && (
              <div className="message processing">
                <div className="message-content">
                  <div className="processing-indicator">
                    <span></span><span></span><span></span>
                  </div>
                  <p>Processing...</p>
                </div>
              </div>
            )}
          </div>

          {/* Live Transcription */}
          {liveTranscription && (
            <div className="live-transcription">
              <div className="transcription-content">
                <span className="transcription-icon">🎤</span>
                <span className="transcription-text">{liveTranscription}</span>
                <div className="waveform" ref={waveformRef}>
                  <span></span><span></span><span></span><span></span><span></span>
                </div>
              </div>
            </div>
          )}

          {/* TTS Progress Bar */}
          {isTtsPlaying && (
            <div className="tts-progress">
              <div className="progress-bar">
                <div 
                  className="progress-fill" 
                  style={{ width: `${ttsProgress}%` }}
                ></div>
              </div>
              <span className="progress-text">🔊 Playing: {ttsProgress.toFixed(1)}%</span>
            </div>
          )}

          <div className="input-section">
            <div className="text-input-container">
              <input
                id="text-input"
                type="text"
                placeholder="Type your message..."
                onKeyPress={(e) => e.key === 'Enter' && sendTextMessage()}
                disabled={isProcessing}
              />
              <button onClick={sendTextMessage} disabled={isProcessing}>
                Send
              </button>
            </div>
            
            <div className="voice-controls">
              <button
                className={`record-button ${isRecording ? 'recording' : ''}`}
                onClick={isRecording ? stopRecording : startRecording}
                disabled={isProcessing}
              >
                {isRecording ? '⏹️ Stop' : '🎤 Record'}
              </button>
              <button
                className={`mute-button ${isMuted ? 'muted' : ''}`}
                onClick={toggleMute}
              >
                {isMuted ? '🔇' : '🔊'}
              </button>
              {explainabilityData && (
                <button
                  className="explainability-button"
                  onClick={openExplainability}
                >
                  🔍 Explain
                </button>
              )}
            </div>
          </div>
        </div>

        {/* Right Column - Context */}
        <div className="right-panel">
          <div className="panel-header">
            <h3>📋 Context Sent to Model</h3>
          </div>
          <div className="context-panel">
            {lastRequestData ? (
              <div className="context-content">
                <div className="context-section">
                  <h4>🎭 Character Context</h4>
                  <div className="character-context">
                    <p><strong>Character:</strong> {selectedCharacter}</p>
                    <p><strong>Personality:</strong> {getSelectedCharacterData()?.personality}</p>
                    <p><strong>Speaking Style:</strong> {getSelectedCharacterData()?.speaking_style}</p>
                  </div>
                </div>

                <div className="context-section">
                  <h4>📝 System Prompt</h4>
                  <div className="system-prompt">
                    <pre>{systemPrompt || 'No system prompt available'}</pre>
                  </div>
                </div>

                <div className="context-section">
                  <h4>⚡ Performance Metrics</h4>
                  <div className="performance-metrics">
                    <div className="metric">
                      <span>STT Latency:</span>
                      <span>{lastRequestData?.stt_latency || 'N/A'} ms</span>
                    </div>
                    <div className="metric">
                      <span>Embedding Query:</span>
                      <span>{lastRequestData?.embedding_latency || 'N/A'} ms</span>
                    </div>
                    <div className="metric">
                      <span>LLM Response:</span>
                      <span>{lastRequestData?.llm_latency || 'N/A'} ms</span>
                    </div>
                    <div className="metric">
                      <span>TTS Generation:</span>
                      <span>{lastRequestData?.tts_latency || 'N/A'} ms</span>
                    </div>
                  </div>
                </div>

                                 <div className="context-section">
                   <h4>🔧 Service Information</h4>
                   <div className="service-info">
                     <p><strong>🤖 LLM Model:</strong> GPT-4 (via OpenAI API)</p>
                     <p><strong>🎤 STT Service:</strong> Whisper (OpenAI)</p>
                     <p><strong>🔊 TTS Service:</strong> ElevenLabs</p>
                     <p><strong>🔍 RAG Database:</strong> PostgreSQL + pgvector</p>
                   </div>
                 </div>

                 <div className="context-section">
                   <h4>📋 System Logs</h4>
                   <div className="logs-container">
                     {logs.map((log, index) => (
                       <div key={index} className="log-entry">
                         {log}
                       </div>
                     ))}
                   </div>
                 </div>
              </div>
            ) : (
              <div className="empty-state">
                <p>No context available yet. Send a message to see what was sent to the model!</p>
              </div>
            )}
          </div>
        </div>
      </div>

             {/* Footer */}
       <footer className="app-footer">
         <div className="footer-left">
           <span className="build-version">Build: {buildVersion}</span>
         </div>
         <div className="footer-center">
           <div className="metrics-footer">
             <div className="metric-item">
               <span className="metric-label">🤖 LLM:</span>
               <span className="metric-value">{performanceMetrics.llm || 0}ms</span>
             </div>
             <div className="metric-item">
               <span className="metric-label">🎤 STT:</span>
               <span className="metric-value">{performanceMetrics.stt || 0}ms</span>
             </div>
             <div className="metric-item">
               <span className="metric-label">🔊 TTS:</span>
               <span className="metric-value">{performanceMetrics.tts || 0}ms</span>
             </div>
             <div className="metric-item">
               <span className="metric-label">⚡ Total:</span>
               <span className="metric-value">{performanceMetrics.total || 0}ms</span>
             </div>
             <div className="metric-item">
               <span className="metric-label">📊 Tokens/sec:</span>
               <span className="metric-value">{performanceMetrics.tokensPerSec ? performanceMetrics.tokensPerSec.toFixed(1) : 0}</span>
             </div>
           </div>
         </div>
         <div className="footer-right">
           <button className="export-button" onClick={exportConversation}>
             💾 Export Conversation
           </button>
         </div>
       </footer>

      {/* Explainability Modal */}
      {showExplainability && explainabilityData && (
        <div className="modal-overlay" onClick={() => setShowExplainability(false)}>
          <div className="explainability-modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2>🔍 AI Explainability Report</h2>
              <button className="close-button" onClick={() => setShowExplainability(false)}>
                ✕
              </button>
            </div>
            
            <div className="modal-content">
              <div className="explainability-section">
                <h3>💬 User Input</h3>
                <p className="user-input">{explainabilityData.userMessage}</p>
              </div>

              <div className="explainability-section">
                <h3>🎭 Character Context</h3>
                <div className="character-context">
                  <p><strong>Character:</strong> {explainabilityData.character}</p>
                  <p><strong>Personality:</strong> {getSelectedCharacterData()?.personality}</p>
                  <p><strong>Speaking Style:</strong> {getSelectedCharacterData()?.speaking_style}</p>
                </div>
              </div>

              <div className="explainability-section">
                <h3>🎬 Retrieved Movie Lines ({explainabilityData.ragContext.length} results)</h3>
                <div className="movie-lines">
                  {explainabilityData.ragContext.map((context, index) => (
                    <div key={index} className="movie-line">
                      <div className="movie-line-header">
                        <span className="movie-title">{context.movie_title}</span>
                        <span className="scene-info">{context.scene_info}</span>
                        <span className="relevance-score">Relevance: {context.similarity_score ? context.similarity_score.toFixed(3) : 'N/A'}</span>
                      </div>
                      <div className="movie-dialogue">
                        <strong>Dialogue:</strong> "{context.dialogue}"
                      </div>
                      <div className="movie-context">
                        <strong>Context:</strong> {context.context || 'No additional context available'}
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div className="explainability-section">
                <h3>🤖 System Prompt</h3>
                <div className="system-prompt">
                  <pre>{explainabilityData.systemPrompt}</pre>
                </div>
              </div>

              <div className="explainability-section">
                <h3>💭 AI Response</h3>
                <div className="ai-response">
                  <p>{explainabilityData.llmResponse}</p>
                </div>
              </div>

              <div className="explainability-section">
                <h3>⚡ Performance Analysis</h3>
                <div className="performance-analysis">
                  <div className="performance-item">
                    <span>STT Processing:</span>
                    <span>{explainabilityData.performance.stt}ms</span>
                  </div>
                  <div className="performance-item">
                    <span>LLM Generation:</span>
                    <span>{explainabilityData.performance.llm}ms</span>
                  </div>
                  <div className="performance-item">
                    <span>Total Response Time:</span>
                    <span>{explainabilityData.performance.total}ms</span>
                  </div>
                </div>
              </div>

              <div className="explainability-section">
                <h3>📊 Technical Details</h3>
                <div className="technical-details">
                  <p><strong>Timestamp:</strong> {new Date(explainabilityData.timestamp).toLocaleString()}</p>
                  <p><strong>Character:</strong> {explainabilityData.character}</p>
                  <p><strong>RAG Results:</strong> {explainabilityData.ragContext.length} movie lines retrieved</p>
                  <p><strong>Response Length:</strong> {explainabilityData.llmResponse.length} characters</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
