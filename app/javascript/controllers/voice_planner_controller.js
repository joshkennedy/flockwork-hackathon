import { Controller } from "@hotwired/stimulus"

const SAMPLE_RATE = 24000

export default class extends Controller {
  static targets = [
    "assistantCaption",
    "cardState",
    "error",
    "launcher",
    "panel",
    "startButton",
    "status",
    "userCaption"
  ]

  static values = {
    answerUrl: String,
    voiceSessionUrl: String
  }

  connect() {
    this.supported = Boolean(navigator.mediaDevices?.getUserMedia && window.WebSocket)
    this.active = false
    this.intentionalClose = false
    this.answerInFlight = false
    this.lastCardKey = this.cardKey()
    this.updateLaunchers()

    this.cardObserver = new MutationObserver(() => this.plannerChanged())
    this.cardObserver.observe(this.element, { childList: true, subtree: true })
  }

  disconnect() {
    this.cardObserver?.disconnect()
    this.stopConversation()
  }

  launcherTargetConnected() {
    this.updateLaunchers()
  }

  async start(event) {
    event.preventDefault()
    if (!this.supported || this.active) return

    this.clearError()
    this.active = true
    this.intentionalClose = false
    this.answerInFlight = false
    this.assistantText = ""
    this.userText = ""
    this.panelTarget.hidden = false
    this.assistantCaptionTarget.textContent = "Waiting to speak…"
    this.userCaptionTarget.textContent = "Listening…"
    this.setStatus("Listening…")
    this.updateLaunchers()

    const streamPromise = navigator.mediaDevices.getUserMedia({
      audio: {
        channelCount: 1,
        echoCancellation: true,
        noiseSuppression: true,
        sampleRate: SAMPLE_RATE
      }
    })
    try {
      const [voiceSession, stream] = await Promise.all([
        this.fetchVoiceSession(),
        streamPromise
      ])
      if (!this.active) {
        stream.getTracks().forEach((track) => track.stop())
        return
      }

      this.stream = stream
      this.setupAudio(stream)
      await this.openSocket(voiceSession)
      this.configureSession(voiceSession)
      this.send({ type: "response.create" })
    } catch (error) {
      streamPromise.then((stream) => stream.getTracks().forEach((track) => track.stop())).catch(() => {})
      this.fail(this.messageFor(error))
    }
  }

  end(event) {
    event?.preventDefault()
    this.stopConversation()
  }

  async plannerChanged() {
    this.updateLaunchers()
    if (!this.active || !this.hasCardStateTarget) return

    const nextKey = this.cardKey()
    if (nextKey === this.lastCardKey) return

    this.lastCardKey = nextKey
    try {
      const voiceSession = await this.fetchVoiceSession()
      if (!this.active) return

      if (!this.socket || this.socket.readyState !== window.WebSocket.OPEN) {
        await this.openSocket(voiceSession)
      }
      this.assistantText = ""
      this.userText = ""
      this.assistantCaptionTarget.textContent = "Waiting to speak…"
      this.userCaptionTarget.textContent = "Listening…"
      this.setStatus("Listening…")
      this.configureSession(voiceSession)
      this.closing = this.cardStateTarget.dataset.voiceState === "reviewing"
      this.send({ type: "response.create" })
    } catch (error) {
      this.fail(this.messageFor(error))
    }
  }

  async fetchVoiceSession() {
    const response = await fetch(this.voiceSessionUrlValue, {
      method: "POST",
      headers: {
        "Accept": "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      credentials: "same-origin"
    })
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(payload.error || "Voice planning could not start. You can keep typing.")
    return payload
  }

  openSocket(voiceSession) {
    return new Promise((resolve, reject) => {
      const url = `wss://api.x.ai/v1/realtime?model=${encodeURIComponent(voiceSession.model)}`
      const socket = new window.WebSocket(url, [ `xai-client-secret.${voiceSession.client_secret}` ])
      this.socket = socket
      socket.binaryType = "arraybuffer"

      socket.onopen = () => resolve()
      socket.onmessage = (event) => this.receive(event)
      socket.onerror = () => reject(new Error("The voice connection failed. You can keep typing."))
      socket.onclose = () => {
        if (this.active && !this.intentionalClose) {
          this.fail("The voice connection closed. You can keep typing.")
        }
      }
    })
  }

  configureSession(voiceSession) {
    this.send({
      type: "session.update",
      session: {
        voice: "eve",
        instructions: voiceSession.instructions,
        turn_detection: { type: "server_vad" },
        audio: {
          input: {
            format: { type: "audio/pcm", rate: SAMPLE_RATE },
            transcription: { model: "grok-transcribe" }
          },
          output: {
            format: { type: "audio/pcm", rate: SAMPLE_RATE }
          }
        },
        tools: voiceSession.tools,
        tool_choice: "auto"
      }
    })
  }

  setupAudio(stream) {
    const AudioContext = window.AudioContext || window.webkitAudioContext
    if (!AudioContext) throw new Error("This browser cannot play voice planning audio. You can keep typing.")

    this.audioContext = new AudioContext({ sampleRate: SAMPLE_RATE })
    this.nextPlaybackTime = this.audioContext.currentTime
    this.mediaSource = this.audioContext.createMediaStreamSource(stream)
    this.processor = this.audioContext.createScriptProcessor(4096, 1, 1)
    this.processor.onaudioprocess = (event) => {
      if (!this.active || this.socket?.readyState !== window.WebSocket.OPEN) return

      const samples = event.inputBuffer.getChannelData(0)
      const resampled = this.resample(samples, this.audioContext.sampleRate, SAMPLE_RATE)
      this.send({ type: "input_audio_buffer.append", audio: this.pcm16Base64(resampled) })
    }
    this.mediaSource.connect(this.processor)
    this.processor.connect(this.audioContext.destination)
  }

  receive(message) {
    if (message.data instanceof ArrayBuffer) {
      this.playPcm16(message.data)
      return
    }

    let event
    try {
      event = JSON.parse(message.data)
    } catch (_error) {
      return
    }

    switch (event.type) {
      case "response.output_audio.delta":
      case "response.audio.delta":
        this.playPcm16(this.base64Buffer(event.delta))
        break
      case "response.output_audio_transcript.delta":
      case "response.audio_transcript.delta":
        this.assistantText += event.delta || ""
        this.assistantCaptionTarget.textContent = this.assistantText
        break
      case "response.output_audio_transcript.done":
      case "response.audio_transcript.done":
        if (event.transcript) this.assistantText = event.transcript
        this.assistantCaptionTarget.textContent = this.assistantText || "Finished speaking."
        break
      case "conversation.item.input_audio_transcription.updated":
      case "conversation.item.input_audio_transcription.completed":
        this.userText = event.transcript || this.userText
        this.userCaptionTarget.textContent = this.userText || "Listening…"
        break
      case "response.function_call_arguments.done":
        this.handleFunctionCall(event)
        break
      case "response.done":
        this.responseFinished()
        break
      case "error":
        this.fail("Voice planning hit an error. You can keep typing.")
        break
    }
  }

  async handleFunctionCall(event) {
    if (event.name !== "answer_card" || this.answerInFlight) return

    let answer
    try {
      answer = JSON.parse(event.arguments).answer
    } catch (_error) {
      this.fail("Grok returned an invalid answer. You can keep typing.")
      return
    }
    if (!answer) return

    this.answerInFlight = true
    this.setStatus("Thinking…")
    try {
      const body = new URLSearchParams({ answer, source: "voice" })
      const response = await fetch(this.answerUrlValue, {
        method: "POST",
        headers: {
          "Accept": "text/html",
          "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
          "X-CSRF-Token": this.csrfToken()
        },
        body,
        credentials: "same-origin"
      })
      if (!response.ok) throw new Error("The spoken answer could not be saved. You can keep typing.")

      this.send({
        type: "conversation.item.create",
        item: {
          type: "function_call_output",
          call_id: event.call_id,
          output: JSON.stringify({ saved: true })
        }
      })
    } catch (error) {
      this.fail(this.messageFor(error))
    } finally {
      this.answerInFlight = false
    }
  }

  responseFinished() {
    const delay = Math.max(0, ((this.nextPlaybackTime || 0) - (this.audioContext?.currentTime || 0)) * 1000)
    window.setTimeout(() => {
      if (!this.active) return
      if (this.closing) {
        this.stopConversation()
      } else if (!this.answerInFlight) {
        this.setStatus("Listening…")
      }
    }, delay)
  }

  playPcm16(buffer) {
    if (!this.audioContext || buffer.byteLength === 0) return

    const pcm = new Int16Array(buffer)
    const audioBuffer = this.audioContext.createBuffer(1, pcm.length, SAMPLE_RATE)
    const channel = audioBuffer.getChannelData(0)
    for (let index = 0; index < pcm.length; index += 1) channel[index] = pcm[index] / 32768

    const source = this.audioContext.createBufferSource()
    source.buffer = audioBuffer
    source.connect(this.audioContext.destination)
    const startAt = Math.max(this.audioContext.currentTime, this.nextPlaybackTime || 0)
    source.start(startAt)
    this.nextPlaybackTime = startAt + audioBuffer.duration
    this.setStatus("Speaking…")
  }

  resample(samples, sourceRate, targetRate) {
    if (sourceRate === targetRate) return samples

    const outputLength = Math.max(1, Math.round(samples.length * targetRate / sourceRate))
    const output = new Float32Array(outputLength)
    const scale = (samples.length - 1) / Math.max(1, outputLength - 1)
    for (let index = 0; index < outputLength; index += 1) {
      const position = index * scale
      const left = Math.floor(position)
      const right = Math.min(samples.length - 1, left + 1)
      const mix = position - left
      output[index] = samples[left] * (1 - mix) + samples[right] * mix
    }
    return output
  }

  pcm16Base64(samples) {
    const pcm = new Int16Array(samples.length)
    for (let index = 0; index < samples.length; index += 1) {
      const sample = Math.max(-1, Math.min(1, samples[index]))
      pcm[index] = sample < 0 ? sample * 32768 : sample * 32767
    }

    const bytes = new Uint8Array(pcm.buffer)
    let binary = ""
    for (let index = 0; index < bytes.length; index += 1) binary += String.fromCharCode(bytes[index])
    return window.btoa(binary)
  }

  base64Buffer(value) {
    const binary = window.atob(value || "")
    const bytes = new Uint8Array(binary.length)
    for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index)
    return bytes.buffer
  }

  send(event) {
    if (this.socket?.readyState === window.WebSocket.OPEN) {
      this.socket.send(JSON.stringify(event))
    }
  }

  stopConversation() {
    if (!this.active && !this.socket && !this.stream && !this.audioContext) return

    this.active = false
    this.closing = false
    this.intentionalClose = true
    this.processor?.disconnect()
    this.mediaSource?.disconnect()
    this.stream?.getTracks().forEach((track) => track.stop())
    this.audioContext?.close()
    if (this.socket && this.socket.readyState < window.WebSocket.CLOSED) this.socket.close()
    this.processor = null
    this.mediaSource = null
    this.stream = null
    this.audioContext = null
    this.socket = null
    if (this.hasPanelTarget) this.panelTarget.hidden = true
    this.updateLaunchers()
  }

  fail(message) {
    this.stopConversation()
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
  }

  clearError() {
    this.errorTarget.textContent = ""
    this.errorTarget.hidden = true
  }

  updateLaunchers() {
    if (!this.hasLauncherTarget) return

    this.launcherTargets.forEach((launcher) => {
      launcher.hidden = !this.supported || this.active
    })
    this.startButtonTargets.forEach((button) => {
      button.disabled = this.active
    })
  }

  cardKey() {
    if (!this.hasCardStateTarget) return ""
    return `${this.cardStateTarget.dataset.voiceState}:${this.cardStateTarget.dataset.voiceCard || ""}`
  }

  setStatus(status) {
    if (this.hasStatusTarget) this.statusTarget.textContent = status
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  messageFor(error) {
    if (error?.name === "NotAllowedError") return "Microphone access was denied. You can keep typing."
    return error?.message || "Voice planning is unavailable. You can keep typing."
  }
}
