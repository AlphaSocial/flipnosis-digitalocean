import { useState, useEffect } from 'react'
import webSocketService from '../../../services/WebSocketService'
import { useToast } from '../../../contexts/ToastContext'

export const useGameRoomWebSocket = (gameId, address, gameData) => {
  const { showError, showInfo } = useToast()
  const [wsConnected, setWsConnected] = useState(false)
  const [wsRef, setWsRef] = useState(null)

  // Initialize WebSocket connection for game room (private 2-player room)
  const initializeWebSocket = async () => {
    if (!gameId || !address) {
      console.log('⚠️ Cannot initialize game room WebSocket - missing gameId or address')
      return
    }

    try {
      console.log('🔌 Initializing game room WebSocket connection for game:', gameId)
      
      // Connect using the WebSocket service with private game room
      const gameRoomId = `game_room_${gameId}` // Private room for 2 players only
      const ws = await webSocketService.connect(gameRoomId, address)
      if (ws) {
        setWsRef(ws)
        setWsConnected(true)
        console.log('✅ Game room WebSocket connection established successfully')
      } else {
        console.error('❌ Failed to connect game room WebSocket')
        setWsConnected(false)
      }
    } catch (error) {
      console.error('❌ Failed to initialize game room WebSocket:', error)
      setWsConnected(false)
    }
  }

  // Set up connection state monitoring
  useEffect(() => {
    const checkConnectionState = () => {
      try {
        if (webSocketService && typeof webSocketService.isConnected === 'function') {
          const isConnected = webSocketService.isConnected()
          setWsConnected(isConnected)
        } else {
          const ws = webSocketService?.getWebSocket?.()
          const connected = ws && ws.readyState === WebSocket.OPEN
          setWsConnected(connected)
        }
      } catch (error) {
        console.error('❌ Error checking game room WebSocket connection:', error)
        setWsConnected(false)
      }
    }

    const interval = setInterval(checkConnectionState, 2000)
    
    return () => {
      clearInterval(interval)
    }
  }, [])

  // Initialize WebSocket when game data is available
  useEffect(() => {
    if (gameId && address && gameData) {
      initializeWebSocket()
    }

    return () => {
      // Cleanup will be handled by the WebSocket service
    }
  }, [gameId, address, gameData])

  // Game room specific message handlers
  const handlePlayerChoice = (choice) => {
    try {
      if (!webSocketService || typeof webSocketService.isConnected !== 'function') {
        showError('WebSocket service not available')
        return
      }
      
      if (!webSocketService.isConnected()) {
        showError('Not connected to game server')
        return
      }

      // Validate choice
      if (!['heads', 'tails'].includes(choice)) {
        console.error('❌ Invalid choice:', choice)
        return
      }

      // Determine the opposite choice for the other player
      const oppositeChoice = choice === 'heads' ? 'tails' : 'heads'

      // Send choice to server via WebSocket
      webSocketService.send({
        type: 'GAME_ACTION',
        gameId,
        action: 'MAKE_CHOICE',
        choice,
        oppositeChoice,
        player: address
      })
    } catch (error) {
      console.error('❌ Error in handlePlayerChoice:', error)
      showError('Failed to send choice to server')
    }
  }

  const handlePowerChargeStart = () => {
    try {
      if (webSocketService && typeof webSocketService.isConnected === 'function' && webSocketService.isConnected()) {
        webSocketService.send({
          type: 'GAME_ACTION',
          gameId,
          action: 'POWER_CHARGE_START',
          player: address
        })
      }
    } catch (error) {
      console.error('❌ Error in handlePowerChargeStart:', error)
      showError('Failed to send power charge start to server')
    }
  }

  const handlePowerChargeStop = async (powerLevel) => {
    try {
      if (!webSocketService || typeof webSocketService.isConnected !== 'function') {
        showError('WebSocket service not available')
        return
      }
      
      if (!webSocketService.isConnected()) {
        showError('Not connected to game server')
        return
      }

      const validPowerLevel = typeof powerLevel === 'number' && !isNaN(powerLevel) ? powerLevel : 5

      // Send power charge completion to server
      webSocketService.send({
        type: 'GAME_ACTION',
        gameId,
        action: 'POWER_CHARGED',
        player: address,
        powerLevel: validPowerLevel
      })
    } catch (error) {
      console.error('❌ Error in handlePowerChargeStop:', error)
      showError('Failed to send power charge to server')
    }
  }

  const handleForfeit = () => {
    try {
      if (webSocketService && typeof webSocketService.isConnected === 'function' && webSocketService.isConnected()) {
        webSocketService.send({
          type: 'GAME_ACTION',
          gameId,
          action: 'FORFEIT_GAME',
          player: address
        })
        showInfo('Game forfeited. Your opponent wins.')
      }
    } catch (error) {
      console.error('❌ Error in handleForfeit:', error)
      showError('Failed to forfeit game')
    }
  }

  // Detect disconnect and warn about forfeit
  useEffect(() => {
    const handleBeforeUnload = (event) => {
      if (wsConnected) {
        const message = 'If you leave now, you will forfeit the game. Are you sure?'
        event.returnValue = message
        return message
      }
    }

    const handleVisibilityChange = () => {
      if (document.hidden && wsConnected) {
        console.log('⚠️ Tab hidden - player may be leaving')
        // Could implement a timer here to forfeit if hidden too long
      }
    }

    window.addEventListener('beforeunload', handleBeforeUnload)
    document.addEventListener('visibilitychange', handleVisibilityChange)

    return () => {
      window.removeEventListener('beforeunload', handleBeforeUnload)
      document.removeEventListener('visibilitychange', handleVisibilityChange)
    }
  }, [wsConnected])

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (webSocketService && typeof webSocketService.disconnect === 'function') {
        webSocketService.disconnect()
      }
    }
  }, [wsRef])

  return {
    wsConnected,
    wsRef: webSocketService?.getWebSocket?.() || null,
    webSocketService,
    handlePlayerChoice,
    handlePowerChargeStart,
    handlePowerChargeStop,
    handleForfeit
  }
}
