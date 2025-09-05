import React, { useState, useEffect, useRef } from 'react';
import axios from 'axios';
import { Container, Row, Col, Card, Button, Form, Badge, Alert, Spinner, Modal, Navbar, Nav, Dropdown, ButtonGroup } from 'react-bootstrap';
import 'bootstrap/dist/css/bootstrap.min.css';
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
  const [selectedModel, setSelectedModel] = useState('tinyllama');
  const [availableModels, setAvailableModels] = useState({});
  const [userInput, setUserInput] = useState('');
  const [showSidebar, setShowSidebar] = useState(false);
  const [showReadme, setShowReadme] = useState(false);
  
  // Character statistics from the processed data
  const characterStats = {
    "Luke Skywalker": 443,
    "Darth Vader": 127,
    "Yoda": 58,
    "Han Solo": 427,
    "Princess Leia": 241,
    "Obi-Wan Kenobi": 109,
    "C-3PO": 269,
    "R2-D2": 12,
    "Chewbacca": 17,
    "Lando": 111,
    "Emperor Palpatine": 24,
    "Grand Moff Tarkin": 24
  };
  
  // Calculate total movie lines
  const totalMovieLines = Object.values(characterStats).reduce((sum, count) => sum + count, 0);
  
  // Available models
  const models = {
    'phi-2': {
      name: 'Phi-2',
      description: 'Microsoft Phi-2 (2.7B parameters)',
      port: 'http://209.38.89.159:5003',
      icon: '🤖',
      color: '#4A90E2'
    },
    'tinyllama': {
      name: 'TinyLlama',
      description: 'TinyLlama (1.1B parameters)',
      port: 'http://209.38.89.159:5004',
      icon: '⚡',
      color: '#27AE60'
    }
  };
  
  const mediaRecorderRef = useRef(null);
  const audioChunksRef = useRef([]);
  const audioRef = useRef(null);
  const waveformRef = useRef(null);
  const messagesEndRef = useRef(null);

  const characters = [
    { 
      name: 'Luke Skywalker', 
      emoji: '⚔️',
      color: '#4a90e2',
      voice: 'en-us',
      speed: 1.2,
      personality: 'Optimistic, brave, determined, and committed to doing what\'s right. He believes in the Force and the power of good.',
      speaking_style: 'Respond as a hopeful, moral, and reflective Jedi, seeking wisdom and balance.'
    },
    { 
      name: 'Darth Vader', 
      emoji: '🖤',
      color: '#e74c3c',
      voice: 'en',
      speed: 0.8,
      personality: 'Intimidating, commanding, conflicted, and powerful. He is both feared and respected.',
      speaking_style: 'Use deep, commanding, ominous tone with decisive, threatening authority.'
    },
    { 
      name: 'Yoda', 
      emoji: '🟢',
      color: '#27ae60',
      voice: 'en-gb',
      speed: 0.7,
      personality: 'Wise, patient, philosophical, and deeply connected to the Force. He speaks in a unique, backwards manner.',
      speaking_style: 'Talk like a wise, cryptic mentor with reversed word order and deep insight.'
    },
    { 
      name: 'Han Solo', 
      emoji: '🤠',
      color: '#f39c12',
      voice: 'en-au',
      speed: 1.1,
      personality: 'Confident, sarcastic, loyal, and resourceful. He\'s a bit of a rogue but has a heart of gold.',
      speaking_style: 'Speak like a sarcastic, confident smuggler with quick wit and daring attitude.'
    },
    { 
      name: 'Princess Leia', 
      emoji: '👑',
      color: '#9b59b6',
      voice: 'en-gb',
      speed: 1.0,
      personality: 'Strong-willed, intelligent, courageous, and determined. She\'s a natural leader and diplomat.',
      speaking_style: 'Be assertive, intelligent, and compassionate, leading with diplomacy and courage.'
    },
    { 
      name: 'Obi-Wan Kenobi', 
      emoji: '🧙‍♂️',
      color: '#3498db',
      voice: 'en-gb',
      speed: 0.9,
      personality: 'Wise, patient, diplomatic, has a dry sense of humor, mentor figure',
      speaking_style: 'Respond calmly, with measured wisdom, subtle humor, and Jedi patience.'
    }
  ];

  const selectedCharacterData = characters.find(char => char.name === selectedCharacter);

  // Auto-scroll to bottom of messages
  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  // Scroll to top when component loads
  const scrollToTop = () => {
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  // Scroll to top on initial load
  useEffect(() => {
    scrollToTop();
  }, []);

  // Health check
  useEffect(() => {
    const checkHealth = async () => {
      try {
        const response = await axios.get('http://209.38.89.159:5003/health');
        setConnectionStatus('healthy');
      } catch (error) {
        setConnectionStatus('error');
      }
    };
    checkHealth();
    const interval = setInterval(checkHealth, 30000);
    return () => clearInterval(interval);
  }, []);

  const sendMessage = async () => {
    if (!userInput.trim() || isProcessing) return;

    const userMessage = userInput.trim();
    setUserInput('');
    setIsProcessing(true);

    // Add user message
    const newUserMessage = {
      id: Date.now(),
      type: 'user',
      content: userMessage,
      timestamp: new Date().toLocaleTimeString()
    };
    setMessages(prev => [...prev, newUserMessage]);

    try {
      const selectedModelData = models[selectedModel];
      const response = await axios.post(`${selectedModelData.port}/chat`, {
        character: selectedCharacter,
        message: userMessage
      });

      const characterMessage = {
        id: Date.now() + 1,
        type: 'character',
        content: response.data.response,
        timestamp: new Date().toLocaleTimeString(),
        character: selectedCharacter
      };
      setMessages(prev => [...prev, characterMessage]);

      // Update RAG context if available
      if (response.data.rag_context) {
        setRagContext(response.data.rag_context);
      }

      // Store explainability data
      setExplainabilityData(response.data);

    } catch (error) {
      console.error('Error sending message:', error);
      const errorMessage = {
        id: Date.now() + 1,
        type: 'error',
        content: 'Sorry, I encountered an error. Please try again.',
        timestamp: new Date().toLocaleTimeString()
      };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  const clearChat = () => {
    setMessages([]);
    setRagContext([]);
    setExplainabilityData(null);
  };

  // Speech-to-Text functionality
  const startRecording = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mediaRecorder = new MediaRecorder(stream);
      const audioChunks = [];

      mediaRecorder.ondataavailable = (event) => {
        audioChunks.push(event.data);
      };

      mediaRecorder.onstop = async () => {
        const audioBlob = new Blob(audioChunks, { type: 'audio/wav' });
        await sendAudioToSTT(audioBlob);
        stream.getTracks().forEach(track => track.stop());
      };

      mediaRecorder.start();
      mediaRecorderRef.current = mediaRecorder;
      audioChunksRef.current = audioChunks;
      setIsRecording(true);
      setLiveTranscription('Listening...');
    } catch (error) {
      console.error('Error starting recording:', error);
      alert('Error accessing microphone. Please check permissions.');
    }
  };

  const stopRecording = () => {
    if (mediaRecorderRef.current && isRecording) {
      mediaRecorderRef.current.stop();
      setIsRecording(false);
      setLiveTranscription('');
    }
  };

  const sendAudioToSTT = async (audioBlob) => {
    try {
      const formData = new FormData();
      formData.append('file', audioBlob, 'recording.wav');

      const response = await axios.post('http://209.38.89.159:5001/transcribe', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });

      const transcribedText = response.data.text;
      setUserInput(transcribedText);
      setLiveTranscription(`Transcribed: "${transcribedText}"`);
      
      // Auto-send the transcribed message after a short delay
      setTimeout(() => {
        setLiveTranscription('');
      }, 3000);
    } catch (error) {
      console.error('Error transcribing audio:', error);
      setLiveTranscription('Error transcribing audio. Please try again.');
    }
  };

  const handleRecordingToggle = () => {
    if (isRecording) {
      stopRecording();
    } else {
      startRecording();
    }
  };

  const getConnectionStatusBadge = () => {
    switch (connectionStatus) {
      case 'healthy':
        return <Badge bg="success">🟢 Connected</Badge>;
      case 'error':
        return <Badge bg="danger">🔴 Error</Badge>;
      default:
        return <Badge bg="warning">🟡 Checking...</Badge>;
    }
  };

  return (
    <div className="app">
      {/* Navigation Bar */}
      <Navbar bg="dark" variant="dark" expand="lg" className="border-bottom border-secondary">
        <Container fluid>
          <Navbar.Brand className="d-flex align-items-center">
            <span className="me-2">⭐</span>
            <span className="fw-bold">Star Wars Chat</span>
          </Navbar.Brand>
          
          <div className="d-flex align-items-center me-3">
            {getConnectionStatusBadge()}
          </div>

          <Navbar.Toggle 
            aria-controls="sidebar-nav" 
            onClick={() => setShowSidebar(!showSidebar)}
            className="d-lg-none"
          />
          
          <Navbar.Collapse id="sidebar-nav" className="justify-content-end">
            <Nav className="ms-auto">
              <Dropdown as={Nav.Item} className="me-2">
                <Dropdown.Toggle as={Nav.Link} className="text-light">
                  {selectedCharacterData?.emoji} {selectedCharacter}
                </Dropdown.Toggle>
                <Dropdown.Menu bg="dark" variant="dark">
                  {characters.map(char => (
                    <Dropdown.Item 
                      key={char.name}
                      onClick={() => setSelectedCharacter(char.name)}
                      className={selectedCharacter === char.name ? 'active' : ''}
                    >
                      {char.emoji} {char.name}
                    </Dropdown.Item>
                  ))}
                </Dropdown.Menu>
              </Dropdown>
              
              <Dropdown as={Nav.Item}>
                <Dropdown.Toggle as={Nav.Link} className="text-light">
                  {models[selectedModel]?.icon} {models[selectedModel]?.name}
                </Dropdown.Toggle>
                <Dropdown.Menu bg="dark" variant="dark">
                  {Object.entries(models).map(([key, model]) => (
                    <Dropdown.Item 
                      key={key}
                      onClick={() => setSelectedModel(key)}
                      className={selectedModel === key ? 'active' : ''}
                    >
                      {model.icon} {model.name}
                    </Dropdown.Item>
                  ))}
                </Dropdown.Menu>
              </Dropdown>
            </Nav>
          </Navbar.Collapse>
        </Container>
      </Navbar>

      <Container fluid className="main-container">
        <Row className="h-100">
          {/* Sidebar - Hidden on mobile, shown on desktop */}
          <Col lg={3} className={`sidebar ${showSidebar ? 'show' : ''} d-none d-lg-block`}>
            <Card className="h-100 border-0 bg-dark text-light">
              <Card.Header className="bg-secondary border-0">
                <h5 className="mb-0">🎬 Movie Context</h5>
              </Card.Header>
              <Card.Body className="p-0">
                <div className="rag-context-container">
                  {ragContext.length > 0 ? (
                    ragContext.map((line, index) => (
                      <div key={index} className="rag-context-item">
                        <div className="d-flex justify-content-between align-items-start mb-2">
                          <small className="text-primary fw-bold">{line.movie_title || 'Star Wars'}</small>
                          <Badge bg="secondary" className="fs-6">
                            {(line.similarity_score || line.similarity || line.score || 0).toFixed(3)}
                          </Badge>
                        </div>
                        <div className="rag-dialogue">
                          <strong className="text-warning">{line.character}:</strong> {line.dialogue}
                        </div>
                      </div>
                    ))
                  ) : (
                    <div className="text-center text-muted p-4">
                      <p className="mb-0">No context retrieved yet. Send a message to see relevant dialogue!</p>
                    </div>
                  )}
                </div>
              </Card.Body>
            </Card>
          </Col>

          {/* Main Chat Area */}
          <Col lg={6} className="chat-area">
            <Card className="h-100 border-0 bg-dark text-light">
              <Card.Header className="bg-secondary border-0 d-flex justify-content-between align-items-center">
                <div>
                  <h5 className="mb-0">💬 Chat with {selectedCharacter}</h5>
                  <small className="text-muted">
                    {characterStats[selectedCharacter] || 0} total lines • {totalMovieLines} total movie lines
                  </small>
                </div>
                <ButtonGroup size="sm">
                  <Button variant="outline-light" onClick={clearChat}>
                    🗑️ Clear
                  </Button>
                  <Button 
                    variant={explainabilityData ? "outline-info" : "outline-secondary"} 
                    onClick={() => setShowExplainability(true)}
                    disabled={!explainabilityData}
                  >
                    🔍 Explain
                  </Button>
                </ButtonGroup>
              </Card.Header>
              
              <Card.Body className="p-0 d-flex flex-column">
                {/* Messages Container */}
                <div className="messages-container flex-grow-1">
                  {messages.length === 0 ? (
                    <div className="text-center text-muted p-5">
                      <h4>🌟 Welcome to Star Wars Chat!</h4>
                      <p>Choose a character and start chatting to experience the magic of the Force.</p>
                      <div className="character-grid mt-4">
                        {characters.map(char => (
                          <Button
                            key={char.name}
                            variant={selectedCharacter === char.name ? 'primary' : 'outline-secondary'}
                            size="sm"
                            className="m-1"
                            onClick={() => setSelectedCharacter(char.name)}
                          >
                            {char.emoji} {char.name}
                          </Button>
                        ))}
                      </div>
                    </div>
                  ) : (
                    messages.map((message) => (
                      <div key={message.id} className={`message ${message.type}`}>
                        <div className={`message-bubble ${message.type}`}>
                          <div className="message-content">
                            {message.type === 'character' && (
                              <div className="character-info mb-2">
                                <span className="character-emoji">{selectedCharacterData?.emoji}</span>
                                <span className="character-name">{message.character}</span>
                              </div>
                            )}
                            {message.content}
                          </div>
                          <small className="message-time">{message.timestamp}</small>
                        </div>
                      </div>
                    ))
                  )}
                  {isProcessing && (
                    <div className="message character">
                      <div className="message-bubble character">
                        <div className="d-flex align-items-center">
                          <Spinner animation="border" size="sm" className="me-2" />
                          <span>Thinking...</span>
                        </div>
                      </div>
                    </div>
                  )}
                  <div ref={messagesEndRef} />
                </div>

                {/* Input Area */}
                <div className="input-area p-3 border-top border-secondary">
                  <Row className="g-2">
                    <Col>
                      <Form.Control
                        as="textarea"
                        rows={2}
                        value={userInput}
                        onChange={(e) => setUserInput(e.target.value)}
                        onKeyPress={handleKeyPress}
                        placeholder={`Message ${selectedCharacter}...`}
                        className="bg-dark text-light border-secondary"
                      />
                    </Col>
                    <Col xs="auto">
                      <Button 
                        variant="primary" 
                        onClick={sendMessage}
                        disabled={!userInput.trim() || isProcessing}
                        className="h-100"
                      >
                        {isProcessing ? <Spinner animation="border" size="sm" /> : 'Send'}
                      </Button>
                    </Col>
                  </Row>
                  
                  {/* Live Transcription */}
                  {liveTranscription && (
                    <div className="live-transcription mt-2 p-2 bg-secondary rounded">
                      <small className="text-light">
                        <strong>🎤 Live:</strong> {liveTranscription}
                      </small>
                    </div>
                  )}

                  {/* Voice Controls */}
                  <div className="voice-controls mt-2 d-flex justify-content-center gap-2">
                    <Button 
                      variant={isRecording ? 'danger' : 'outline-secondary'}
                      size="sm"
                      onClick={handleRecordingToggle}
                    >
                      {isRecording ? '⏹️ Stop' : '🎤 Record'}
                    </Button>
                    <Button 
                      variant={isMuted ? 'secondary' : 'outline-secondary'}
                      size="sm"
                      onClick={() => setIsMuted(!isMuted)}
                    >
                      {isMuted ? '🔊 Unmute' : '🔇 Mute'}
                    </Button>
                    <Button 
                      variant="outline-info"
                      size="sm"
                      onClick={() => setShowReadme(true)}
                    >
                      📖 README
                    </Button>
                  </div>
                </div>
              </Card.Body>
            </Card>
          </Col>

          {/* Info Panel - Hidden on mobile, shown on desktop */}
          <Col lg={3} className="info-panel d-none d-lg-block">
            <Card className="h-100 border-0 bg-dark text-light">
              <Card.Header className="bg-secondary border-0">
                <h5 className="mb-0">⚙️ System Info</h5>
              </Card.Header>
              <Card.Body>
                <div className="info-section mb-3">
                  <h6 className="text-primary">Character Info</h6>
                  <p className="mb-1"><strong>Name:</strong> {selectedCharacter}</p>
                  <p className="mb-1"><strong>Personality:</strong> {selectedCharacterData?.personality}</p>
                  <p className="mb-0"><strong>Style:</strong> {selectedCharacterData?.speaking_style}</p>
                </div>

                <div className="info-section mb-3">
                  <h6 className="text-primary">Model Info</h6>
                  <p className="mb-1"><strong>Model:</strong> {models[selectedModel]?.name}</p>
                  <p className="mb-1"><strong>Description:</strong> {models[selectedModel]?.description}</p>
                  <p className="mb-0"><strong>Port:</strong> {models[selectedModel]?.port}</p>
                </div>

                <div className="info-section mb-3">
                  <h6 className="text-primary">Performance</h6>
                  <p className="mb-1"><strong>Messages:</strong> {messages.length}</p>
                  <p className="mb-1"><strong>Context Lines:</strong> {ragContext.length}</p>
                  <p className="mb-0"><strong>Status:</strong> {connectionStatus}</p>
                </div>

                <div className="info-section mb-3">
                  <h6 className="text-primary">Database Stats</h6>
                  <p className="mb-1"><strong>Character Lines:</strong> {characterStats[selectedCharacter] || 0}</p>
                  <p className="mb-1"><strong>Total Movie Lines:</strong> {totalMovieLines}</p>
                  <p className="mb-0"><strong>Characters Available:</strong> {Object.keys(characterStats).length}</p>
                </div>

                <div className="info-section">
                  <h6 className="text-primary">Build Info</h6>
                  <p className="mb-0"><strong>Version:</strong> {buildVersion}</p>
                </div>
              </Card.Body>
            </Card>
          </Col>
        </Row>
      </Container>

      {/* Explainability Modal */}
      <Modal 
        show={showExplainability} 
        onHide={() => setShowExplainability(false)}
        size="xl"
        className="explainability-modal"
      >
        <Modal.Header closeButton className="bg-dark text-light">
          <Modal.Title>🔍 AI Explainability Report</Modal.Title>
        </Modal.Header>
        <Modal.Body className="bg-dark text-light">
          {explainabilityData && (
            <div>
              {/* User Input Section */}
              <div className="explainability-section mb-4">
                <h6 className="text-primary mb-3">💬 User Input</h6>
                <div className="bg-secondary p-3 rounded">
                  <p className="mb-0">{explainabilityData.request_data?.message || 'No user input available'}</p>
                </div>
              </div>

              {/* Character Context Section */}
              <div className="explainability-section mb-4">
                <h6 className="text-primary mb-3">🎭 Character Context</h6>
                <div className="bg-secondary p-3 rounded">
                  <p className="mb-1"><strong>Character:</strong> {explainabilityData.request_data?.character}</p>
                  <p className="mb-1"><strong>Personality:</strong> {selectedCharacterData?.personality}</p>
                  <p className="mb-1"><strong>Speaking Style:</strong> {selectedCharacterData?.speaking_style}</p>
                  <p className="mb-0"><strong>Model Used:</strong> {models[selectedModel]?.name} ({models[selectedModel]?.description})</p>
                </div>
              </div>

              {/* RAG Context Section */}
              <div className="explainability-section mb-4">
                <h6 className="text-primary mb-3">🎬 Retrieved Movie Lines ({explainabilityData.rag_context?.length || 0} results)</h6>
                <div className="rag-context-modal">
                  {explainabilityData.rag_context && explainabilityData.rag_context.length > 0 ? (
                    explainabilityData.rag_context.map((context, index) => (
                      <div key={index} className="rag-context-item-modal mb-3">
                        <div className="d-flex justify-content-between align-items-start mb-2">
                          <span className="text-warning fw-bold">{context.movie_title || 'Star Wars'}</span>
                          <Badge bg="secondary">Score: {(context.similarity_score || context.similarity || context.score || 0).toFixed(3)}</Badge>
                        </div>
                        <div className="bg-secondary p-2 rounded">
                          <strong className="text-primary">{context.character}:</strong> "{context.dialogue}"
                        </div>
                        {context.scene_info && (
                          <small className="text-muted">Scene: {context.scene_info}</small>
                        )}
                      </div>
                    ))
                  ) : (
                    <div className="text-center text-muted p-3">
                      <p className="mb-0">No context lines retrieved</p>
                    </div>
                  )}
                </div>
              </div>

              {/* System Prompt Section */}
              {explainabilityData.complete_prompt && (
                <div className="explainability-section mb-4">
                  <h6 className="text-primary mb-3">🤖 System Prompt</h6>
                  <div className="bg-secondary p-3 rounded">
                    <pre className="mb-0 text-light" style={{ fontSize: '0.8rem', whiteSpace: 'pre-wrap' }}>
                      {explainabilityData.complete_prompt}
                    </pre>
                  </div>
                </div>
              )}

              {/* AI Response Section */}
              <div className="explainability-section mb-4">
                <h6 className="text-primary mb-3">💭 AI Response</h6>
                <div className="bg-secondary p-3 rounded">
                  <p className="mb-0">{explainabilityData.response}</p>
                </div>
              </div>

              {/* Performance Metrics Section */}
              <div className="explainability-section mb-4">
                <h6 className="text-primary mb-3">⚡ Performance Metrics</h6>
                <div className="row">
                  <div className="col-md-6">
                    <div className="bg-secondary p-3 rounded mb-2">
                      <strong>Embedding Latency:</strong> {explainabilityData.embedding_latency || 'N/A'} ms
                    </div>
                  </div>
                  <div className="col-md-6">
                    <div className="bg-secondary p-3 rounded mb-2">
                      <strong>Generation Latency:</strong> {explainabilityData.generation_latency || 'N/A'} ms
                    </div>
                  </div>
                  <div className="col-md-6">
                    <div className="bg-secondary p-3 rounded mb-2">
                      <strong>Total Tokens:</strong> {explainabilityData.total_tokens || 'N/A'}
                    </div>
                  </div>
                  <div className="col-md-6">
                    <div className="bg-secondary p-3 rounded mb-2">
                      <strong>Tokens/Second:</strong> {explainabilityData.tokens_per_second || 'N/A'}
                    </div>
                  </div>
                </div>
              </div>

              {/* Technical Details Section */}
              <div className="explainability-section">
                <h6 className="text-primary mb-3">📊 Technical Details</h6>
                <div className="bg-secondary p-3 rounded">
                  <p className="mb-1"><strong>Timestamp:</strong> {new Date().toLocaleString()}</p>
                  <p className="mb-1"><strong>Character:</strong> {explainabilityData.request_data?.character}</p>
                  <p className="mb-1"><strong>Character Total Lines:</strong> {characterStats[explainabilityData.request_data?.character] || 0}</p>
                  <p className="mb-1"><strong>RAG Results:</strong> {explainabilityData.rag_context?.length || 0} movie lines retrieved</p>
                  <p className="mb-1"><strong>Total Database Lines:</strong> {totalMovieLines}</p>
                  <p className="mb-0"><strong>Response Length:</strong> {explainabilityData.response?.length || 0} characters</p>
                </div>
              </div>
            </div>
          )}
        </Modal.Body>
      </Modal>

      {/* Mobile Sidebar Overlay */}
      {showSidebar && (
        <div className="mobile-sidebar-overlay" onClick={() => setShowSidebar(false)}>
          <div className="mobile-sidebar" onClick={(e) => e.stopPropagation()}>
            <Card className="h-100 border-0 bg-dark text-light">
              <Card.Header className="bg-secondary border-0 d-flex justify-content-between align-items-center">
                <h5 className="mb-0">🎬 Movie Context</h5>
                <Button variant="outline-light" size="sm" onClick={() => setShowSidebar(false)}>
                  ✕
                </Button>
              </Card.Header>
              <Card.Body className="p-0">
                <div className="rag-context-container">
                  {ragContext.length > 0 ? (
                    ragContext.map((line, index) => (
                      <div key={index} className="rag-context-item">
                        <div className="d-flex justify-content-between align-items-start mb-2">
                          <small className="text-primary fw-bold">{line.movie_title || 'Star Wars'}</small>
                          <Badge bg="secondary" className="fs-6">
                            {(line.similarity_score || line.similarity || line.score || 0).toFixed(3)}
                          </Badge>
                        </div>
                        <div className="rag-dialogue">
                          <strong className="text-warning">{line.character}:</strong> {line.dialogue}
                        </div>
                      </div>
                    ))
                  ) : (
                    <div className="text-center text-muted p-4">
                      <p className="mb-0">No context retrieved yet.</p>
                    </div>
                  )}
                </div>
              </Card.Body>
            </Card>
          </div>
        </div>
      )}

      {/* README Modal */}
      <Modal 
        show={showReadme} 
        onHide={() => setShowReadme(false)}
        size="lg"
        className="readme-modal"
      >
        <Modal.Header closeButton className="bg-dark text-light">
          <Modal.Title>🚀 Star Wars Chat App - Technical Overview</Modal.Title>
        </Modal.Header>
        <Modal.Body className="bg-dark text-light">
          <div className="readme-content">
            
            {/* Project Overview */}
            <div className="section mb-4">
              <h6 className="text-primary mb-2">🎯 Project Overview</h6>
              <p className="mb-2">Interactive Star Wars character chat application using RAG (Retrieval-Augmented Generation) with real-time speech-to-text and text-to-speech capabilities.</p>
            </div>

            {/* Architecture */}
            <div className="section mb-4">
              <h6 className="text-primary mb-2">🏗️ Architecture</h6>
              <ul className="mb-0">
                <li><strong>Frontend:</strong> React with Bootstrap (Port 3000)</li>
                <li><strong>Backend:</strong> FastAPI microservices architecture</li>
                <li><strong>Database:</strong> PostgreSQL with pgvector extension</li>
                <li><strong>Containerization:</strong> Docker Compose orchestration</li>
              </ul>
            </div>

            {/* AI Models */}
            <div className="section mb-4">
              <h6 className="text-primary mb-2">🤖 AI Models</h6>
              <div className="row">
                <div className="col-6">
                  <strong>Phi-2 (Port 5003):</strong>
                  <ul className="mb-0">
                    <li>Microsoft Phi-2 (2.7B parameters)</li>
                    <li>Higher quality responses</li>
                    <li>More detailed character interactions</li>
                  </ul>
                </div>
                <div className="col-6">
                  <strong>TinyLlama (Port 5004):</strong>
                  <ul className="mb-0">
                    <li>TinyLlama (1.1B parameters)</li>
                    <li>Faster response times</li>
                    <li>Lightweight processing</li>
                  </ul>
                </div>
              </div>
            </div>

            {/* Services */}
            <div className="section mb-4">
              <h6 className="text-primary mb-2">🔧 Microservices</h6>
              <ul className="mb-0">
                <li><strong>STT Service (Port 5001):</strong> OpenAI Whisper for speech-to-text</li>
                <li><strong>TTS Service (Port 5002):</strong> ElevenLabs for text-to-speech</li>
                <li><strong>LLM Services (Ports 5003/5004):</strong> Character-specific AI responses</li>
                <li><strong>PostgreSQL (Port 5432):</strong> Vector database with Star Wars dialogue</li>
              </ul>
            </div>

            {/* RAG System */}
            <div className="section mb-4">
              <h6 className="text-primary mb-2">🧠 RAG System</h6>
              <ul className="mb-0">
                <li><strong>Vector Embeddings:</strong> Sentence transformers for dialogue encoding</li>
                <li><strong>Similarity Search:</strong> pgvector for context retrieval</li>
                <li><strong>Context Injection:</strong> Relevant dialogue injected into prompts</li>
                <li><strong>Character Consistency:</strong> Maintains character personality and style</li>
              </ul>
            </div>

            {/* Data */}
            <div className="section mb-4">
              <h6 className="text-primary mb-2">📊 Data Sources</h6>
              <ul className="mb-0">
                <li><strong>Original Trilogy:</strong> A New Hope, Empire Strikes Back, Return of the Jedi</li>
                <li><strong>Characters:</strong> 12 main characters with 1,847 total dialogue lines</li>
                <li><strong>Processing:</strong> Automated dialogue extraction and character mapping</li>
                <li><strong>Embeddings:</strong> Pre-computed vector representations for fast retrieval</li>
              </ul>
            </div>

            {/* Features */}
            <div className="section mb-4">
              <h6 className="text-primary mb-2">✨ Key Features</h6>
              <ul className="mb-0">
                <li><strong>Voice Interaction:</strong> Real-time speech-to-text and text-to-speech</li>
                <li><strong>Model Switching:</strong> Dynamic selection between Phi-2 and TinyLlama</li>
                <li><strong>Explainability:</strong> Detailed RAG process transparency</li>
                <li><strong>Responsive Design:</strong> Mobile-friendly Bootstrap interface</li>
                <li><strong>Character Stats:</strong> Dialogue line counts and database metrics</li>
              </ul>
            </div>

            {/* Tech Stack */}
            <div className="section">
              <h6 className="text-primary mb-2">🛠️ Tech Stack</h6>
              <ul className="mb-0">
                <li><strong>Frontend:</strong> React, Bootstrap, Axios</li>
                <li><strong>Backend:</strong> FastAPI, Python, Uvicorn</li>
                <li><strong>AI/ML:</strong> Whisper, Sentence Transformers, Local LLMs</li>
                <li><strong>Database:</strong> PostgreSQL, pgvector</li>
                <li><strong>Infrastructure:</strong> Docker, Docker Compose</li>
              </ul>
            </div>

          </div>
        </Modal.Body>
      </Modal>
    </div>
  );
}

export default App;
