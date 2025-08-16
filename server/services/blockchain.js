const ethers = require('ethers')

class BlockchainService {
  constructor(rpcUrl, contractAddress, contractOwnerKey) {
    this.rpcUrl = rpcUrl
    this.contractAddress = contractAddress
    this.contractOwnerKey = contractOwnerKey
    this.provider = new ethers.JsonRpcProvider(rpcUrl)
    this.contractOwnerWallet = contractOwnerKey ? new ethers.Wallet(contractOwnerKey, this.provider) : null
    
    // Updated ABI for simplified contract
    this.CONTRACT_ABI = [
      "function depositNFT(bytes32 gameId, address nftContract, uint256 tokenId)",
      "function depositETH(bytes32 gameId) payable",
      "function depositUSDC(bytes32 gameId, uint256 amount)",
      "function completeGame(bytes32 gameId, address winner)",
      "function isGameReady(bytes32 gameId) view returns (bool)",
      "function getGameParticipants(bytes32 gameId) view returns (address nftPlayer, address cryptoPlayer)",
      "function reclaimNFT(bytes32 gameId)",
      "function reclaimCrypto(bytes32 gameId)",
      "function nftDeposits(bytes32) view returns (address depositor, address nftContract, uint256 tokenId, bool claimed, uint256 depositTime)",
      "function ethDeposits(bytes32) view returns (address depositor, uint256 amount, bool claimed, uint256 depositTime)",
      "function usdcDeposits(bytes32) view returns (address depositor, uint256 amount, bool claimed, uint256 depositTime)",
      "function gameResults(bytes32) view returns (address winner, bool completed, uint256 completionTime)",
      "event NFTDeposited(bytes32 indexed gameId, address indexed depositor, address nftContract, uint256 tokenId)",
      "event ETHDeposited(bytes32 indexed gameId, address indexed depositor, uint256 amount)",
      "event USDCDeposited(bytes32 indexed gameId, address indexed depositor, uint256 amount)",
      "event GameReady(bytes32 indexed gameId, address nftDepositor, address cryptoDepositor)",
      "event GameCompleted(bytes32 indexed gameId, address indexed winner)"
    ]
  }

  hasOwnerWallet() {
    return !!this.contractOwnerWallet
  }

  /**
   * Check if game is ready (both assets deposited)
   */
  async isGameReady(gameId) {
    if (!this.contractOwnerWallet) return { success: false, error: 'Contract wallet not configured' }
    
    try {
      const contract = new ethers.Contract(this.contractAddress, this.CONTRACT_ABI, this.contractOwnerWallet)
      const gameIdBytes32 = ethers.id(gameId)
      
      const isReady = await contract.isGameReady(gameIdBytes32)
      console.log(`🎮 Game ${gameId} ready status:`, isReady)
      
      return { success: true, isReady }
    } catch (error) {
      console.error('❌ Error checking game ready status:', error)
      return { success: false, error: error.message }
    }
  }

  /**
   * Get game participants
   */
  async getGameParticipants(gameId) {
    if (!this.contractOwnerWallet) return { success: false, error: 'Contract wallet not configured' }
    
    try {
      const contract = new ethers.Contract(this.contractAddress, this.CONTRACT_ABI, this.contractOwnerWallet)
      const gameIdBytes32 = ethers.id(gameId)
      
      const [nftPlayer, cryptoPlayer] = await contract.getGameParticipants(gameIdBytes32)
      console.log(`🎮 Game ${gameId} participants:`, { nftPlayer, cryptoPlayer })
      
      return { success: true, nftPlayer, cryptoPlayer }
    } catch (error) {
      console.error('❌ Error getting game participants:', error)
      return { success: false, error: error.message }
    }
  }

  /**
   * Get detailed game state
   */
  async getGameState(gameId) {
    if (!this.contractOwnerWallet) return { success: false, error: 'Contract wallet not configured' }
    
    try {
      const contract = new ethers.Contract(this.contractAddress, this.CONTRACT_ABI, this.contractOwnerWallet)
      const gameIdBytes32 = ethers.id(gameId)
      
      // Get all deposit info
      const nftDeposit = await contract.nftDeposits(gameIdBytes32)
      const ethDeposit = await contract.ethDeposits(gameIdBytes32)
      const usdcDeposit = await contract.usdcDeposits(gameIdBytes32)
      const gameResult = await contract.gameResults(gameIdBytes32)
      
      const gameState = {
        nftDeposit: {
          depositor: nftDeposit.depositor,
          nftContract: nftDeposit.nftContract,
          tokenId: nftDeposit.tokenId.toString(),
          claimed: nftDeposit.claimed,
          depositTime: nftDeposit.depositTime.toString(),
          hasDeposit: nftDeposit.depositor !== '0x0000000000000000000000000000000000000000'
        },
        ethDeposit: {
          depositor: ethDeposit.depositor,
          amount: ethDeposit.amount.toString(),
          claimed: ethDeposit.claimed,
          depositTime: ethDeposit.depositTime.toString(),
          hasDeposit: ethDeposit.depositor !== '0x0000000000000000000000000000000000000000'
        },
        usdcDeposit: {
          depositor: usdcDeposit.depositor,
          amount: usdcDeposit.amount.toString(),
          claimed: usdcDeposit.claimed,
          depositTime: usdcDeposit.depositTime.toString(),
          hasDeposit: usdcDeposit.depositor !== '0x0000000000000000000000000000000000000000'
        },
        gameResult: {
          winner: gameResult.winner,
          completed: gameResult.completed,
          completionTime: gameResult.completionTime.toString()
        },
        isReady: false
      }
      
      // Check if game is ready
      gameState.isReady = gameState.nftDeposit.hasDeposit && 
                         (gameState.ethDeposit.hasDeposit || gameState.usdcDeposit.hasDeposit) &&
                         !gameState.gameResult.completed
      
      console.log(`🎮 Game ${gameId} full state:`, gameState)
      return { success: true, gameState }
    } catch (error) {
      console.error('❌ Error getting game state:', error)
      return { success: false, error: error.message }
    }
  }

  /**
   * Complete game and declare winner (called by backend)
   */
  async completeGameOnChain(gameId, winner) {
    console.log('🏆 Completing game on blockchain:', { gameId, winner })
    
    if (!this.contractOwnerWallet) {
      console.error('❌ Contract owner wallet not configured')
      return { success: false, error: 'Contract wallet not configured' }
    }
    
    try {
      const contract = new ethers.Contract(this.contractAddress, this.CONTRACT_ABI, this.contractOwnerWallet)
      const gameIdBytes32 = ethers.id(gameId)
      
      // Verify game is ready before completing
      const isReady = await contract.isGameReady(gameIdBytes32)
      if (!isReady) {
        return { success: false, error: 'Game is not ready to complete' }
      }
      
      // Get participants to verify winner
      const [nftPlayer, cryptoPlayer] = await contract.getGameParticipants(gameIdBytes32)
      if (winner !== nftPlayer && winner !== cryptoPlayer) {
        return { success: false, error: 'Winner must be one of the game participants' }
      }
      
      console.log('🏆 Calling completeGame:', {
        gameIdBytes32,
        winner,
        participants: { nftPlayer, cryptoPlayer }
      })
      
      const tx = await contract.completeGame(gameIdBytes32, winner)
      
      console.log('⏳ Waiting for transaction confirmation:', tx.hash)
      await tx.wait()
      console.log('✅ Game completed on chain')
      return { success: true, transactionHash: tx.hash }
    } catch (error) {
      console.error('❌ Failed to complete game on chain:', error)
      return { success: false, error: error.message || 'Blockchain transaction failed' }
    }
  }

  /**
   * Monitor game events
   */
  async setupEventListeners(callback) {
    if (!this.contractOwnerWallet) return
    
    try {
      const contract = new ethers.Contract(this.contractAddress, this.CONTRACT_ABI, this.provider)
      
      // Listen for GameReady events
      contract.on('GameReady', (gameId, nftDepositor, cryptoDepositor, event) => {
        console.log('🎮 GameReady event:', {
          gameId: gameId,
          nftDepositor,
          cryptoDepositor,
          blockNumber: event.blockNumber
        })
        
        callback({
          type: 'GameReady',
          gameId: gameId,
          nftDepositor,
          cryptoDepositor,
          event
        })
      })
      
      // Listen for GameCompleted events
      contract.on('GameCompleted', (gameId, winner, event) => {
        console.log('🏆 GameCompleted event:', {
          gameId: gameId,
          winner,
          blockNumber: event.blockNumber
        })
        
        callback({
          type: 'GameCompleted',
          gameId: gameId,
          winner,
          event
        })
      })
      
      console.log('👂 Event listeners set up successfully')
    } catch (error) {
      console.error('❌ Failed to set up event listeners:', error)
    }
  }
}

module.exports = { BlockchainService } 