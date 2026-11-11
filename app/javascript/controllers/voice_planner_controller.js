import { Controller } from "@hotwired/stimulus"
import { toast } from "ding"

const SAMPLE_RATE = 24000

export default class extends Controller {
  static targets = [
    "assistantCaption",
    "cardState",
    "launcher",
    "orb",
    "panel",
    "questionnaire",
    "startButton",
    "status",
    "userCaption"
  ]

  static values = {
    answerUrl: String,
    continueUrl: String,
    selectAnswerUrl: String,
    voiceInstructionsUrl: String,
    voiceSessionUrl: String
  }

  connect() {
    this.supported = Boolean(navigator.mediaDevices?.getUserMedia && window.WebSocket)
    this.active = false
    this.intentionalClose = false
    this.answerInFlight = false
    this.continueInFlight = false
    this.responseActive = false
    this.responseDraining = false
    this.pendingIntro = false
    this.ackPending = false
    this.lastContinuedRevision = null
    this.currentStatus = "Listening…"
    this.assistantText = ""
    this.userText = ""
    this.voiceLevel = 0
    this.lastCardKey = this.cardKey()
    this.updateLaunchers()

    document.addEventListener("visibilitychange", this.visibilityChanged)
    this.cardObserver = new MutationObserver(() => this.plannerChanged())
    this.cardObserver.observe(this.element, { childList: true, subtree: true })
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.visibilityChanged)
    this.cardObserver?.disconnect()
    this.stopConversation()
  }

  launcherTargetConnected() {
    this.updateLaunchers()
  }

  cardStateTargetConnected() {
    this.plannerChanged()
  }

  panelTargetConnected(element) {
    element.hidden = !this.active
  }

  statusTargetConnected(element) {
    element.textContent = this.currentStatus || "Listening…"
  }

  assistantCaptionTargetConnected(element) {
    element.textContent = this.assistantText || "Waiting to speak…"
  }

  userCaptionTargetConnected(element) {
    element.textContent = this.userText || "Listening…"
  }

  orbTargetConnected(element) {
    this.paintOrb(element)
  }

  async start(event) {
    event.preventDefault()
    if (!this.supported || this.active) return

    this.clearError()
    this.active = true
    this.requestWakeLock()
    this.intentionalClose = false
    this.answerInFlight = false
    this.continueInFlight = false
    this.responseActive = false
    this.responseDraining = false
    this.pendingIntro = false
    this.ackPending = false
    this.lastContinuedRevision = null
    this.assistantText = ""
    this.userText = ""
    this.voiceLevel = 0
    this.element.dataset.voiceActive = "true"
    if (this.hasPanelTarget) this.panelTarget.hidden = false
    this.paintCaptions()
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
      this.createResponse()
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

    const phase = this.cardStateTarget.dataset.voicePhase
    if (phase === "error") {
      this.fail("The Planner could not update your plan. You can keep typing.")
      return
    }
    if (phase === "ready") {
      await this.continueBuilder()
      return
    }
    if (phase === "busy") this.setStatus("Adding to your plan…")

    const nextKey = this.cardKey()
    if (nextKey === this.lastCardKey) return

    this.lastCardKey = nextKey
    try {
      const socketOpen = this.socket?.readyState === window.WebSocket.OPEN
      const voiceSession = socketOpen ? await this.fetchVoiceInstructions() : await this.fetchVoiceSession()
      if (!this.active) return

      if (!socketOpen) await this.openSocket(voiceSession)
      this.assistantText = ""
      this.userText = ""
      this.voiceLevel = 0
      this.paintCaptions()
      this.setStatus("Listening…")
      this.configureSession(voiceSession)
      this.closing = this.cardStateTarget.dataset.voiceState === "reviewing"
      if (this.responseActive || this.responseDraining) {
        this.pendingIntro = true
      } else {
        this.createResponse()
      }
    } catch (error) {
      this.fail(this.messageFor(error))
    }
  }

  async continueBuilder() {
    if (!this.hasContinueUrlValue || this.continueInFlight || !this.hasCardStateTarget) return

    const revision = this.cardStateTarget.dataset.voiceRevision
    if (!revision || revision === this.lastContinuedRevision) return

    this.continueInFlight = true
    this.lastContinuedRevision = revision
    try {
      const response = await this.postForm(this.continueUrlValue, { expected_revision: revision })
      await this.replaceBuilder(response)
    } catch (error) {
      this.lastContinuedRevision = null
      this.fail(this.messageFor(error))
    } finally {
      this.continueInFlight = false
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

  async fetchVoiceInstructions() {
    const response = await fetch(this.voiceInstructionsUrlValue, {
      headers: { "Accept": "application/json" },
      credentials: "same-origin"
    })
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(payload.error || "Voice planning could not continue. You can keep typing.")
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
      if (this.currentStatus === "Listening…") this.updateVoiceLevel(this.rms(samples))
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
        this.paintCaptions()
        break
      case "response.output_audio_transcript.done":
      case "response.audio_transcript.done":
        if (event.transcript) this.assistantText = event.transcript
        this.paintCaptions("Finished speaking.")
        break
      case "conversation.item.input_audio_transcription.updated":
      case "conversation.item.input_audio_transcription.completed":
        this.userText = event.transcript || this.userText
        this.paintCaptions()
        break
      case "response.function_call_arguments.done":
        this.handleFunctionCall(event)
        break
      case "response.done":
        this.responseActive = false
        if (this.ackPending) {
          this.ackPending = false
          this.createResponse()
          break
        }
        this.responseFinished()
        break
      case "error":
        this.fail("Voice planning hit an error. You can keep typing.")
        break
    }
  }

  async handleFunctionCall(event) {
    if (event.name !== "answer_card") return

    const builderPhase = this.hasSelectAnswerUrlValue && this.hasCardStateTarget
      ? this.cardStateTarget.dataset.voicePhase
      : null
    if (this.answerInFlight || [ "busy", "ready" ].includes(builderPhase)) {
      this.sendFunctionOutput(event.call_id)
      return
    }

    let answer
    try {
      answer = JSON.parse(event.arguments).answer
    } catch (_error) {
      this.fail("Grok returned an invalid answer. You can keep typing.")
      return
    }
    if (!answer) return

    this.answerInFlight = true
    this.setStatus(this.hasSelectAnswerUrlValue ? "Adding to your plan…" : "Thinking…")
    try {
      const values = { answer, source: "voice" }
      if (this.hasSelectAnswerUrlValue) {
        const revision = this.cardStateTarget.dataset.voiceRevision
        if (!revision) throw new Error("The spoken answer could not be saved. You can keep typing.")
        values.expected_revision = revision
      }
      const url = this.hasSelectAnswerUrlValue ? this.selectAnswerUrlValue : this.answerUrlValue
      if (this.hasSelectAnswerUrlValue) {
        this.sendFunctionOutput(event.call_id)
        // The tool call's own response is still open; a second response.create before its response.done is rejected.
        if (this.responseActive) this.ackPending = true
        else this.createResponse()
      }
      const response = await this.postForm(url, values)
      if (this.hasSelectAnswerUrlValue) await this.replaceBuilder(response)
      if (!this.hasSelectAnswerUrlValue) this.sendFunctionOutput(event.call_id)
    } catch (error) {
      this.fail(this.messageFor(error))
    } finally {
      this.answerInFlight = false
    }
  }

  sendFunctionOutput(callId) {
    this.send({
      type: "conversation.item.create",
      item: {
        type: "function_call_output",
        call_id: callId,
        output: JSON.stringify({ saved: true })
      }
    })
  }

  createResponse() {
    if (this.responseActive) return false

    this.responseActive = true
    this.send({ type: "response.create" })
    return true
  }

  responseFinished() {
    this.responseDraining = true
    const delay = Math.max(0, ((this.nextPlaybackTime || 0) - (this.audioContext?.currentTime || 0)) * 1000)
    window.setTimeout(() => {
      this.responseDraining = false
      if (!this.active) return
      if (this.pendingIntro) {
        this.pendingIntro = false
        this.createResponse()
      } else if (this.closing) {
        this.stopConversation()
      } else if (!this.answerInFlight) {
        const phase = this.hasCardStateTarget ? this.cardStateTarget.dataset.voicePhase : null
        this.setStatus([ "busy", "ready" ].includes(phase) ? "Adding to your plan…" : "Listening…")
      }
    }, delay)
  }

  playPcm16(buffer) {
    if (!this.audioContext || buffer.byteLength === 0) return

    const pcm = new Int16Array(buffer)
    const audioBuffer = this.audioContext.createBuffer(1, pcm.length, SAMPLE_RATE)
    const channel = audioBuffer.getChannelData(0)
    for (let index = 0; index < pcm.length; index += 1) channel[index] = pcm[index] / 32768
    this.updateVoiceLevel(this.rms(channel))
    this.scheduleVoiceLevelRelease()

    const source = this.audioContext.createBufferSource()
    source.buffer = audioBuffer
    source.connect(this.audioContext.destination)
    const startAt = Math.max(this.audioContext.currentTime, this.nextPlaybackTime || 0)
    source.start(startAt)
    this.nextPlaybackTime = startAt + audioBuffer.duration
    this.setStatus("Planner is speaking…")
  }

  rms(samples) {
    if (!samples.length) return 0

    let sum = 0
    for (let index = 0; index < samples.length; index += 1) sum += samples[index] * samples[index]
    return Math.min(1, Math.sqrt(sum / samples.length) * 4)
  }

  updateVoiceLevel(level) {
    const factor = level > this.voiceLevel ? 0.7 : 0.55
    this.voiceLevel += (level - this.voiceLevel) * factor
    if (this.voiceLevel < 0.01) this.voiceLevel = 0
    this.paintOrbs()
  }

  scheduleVoiceLevelRelease() {
    window.clearTimeout(this.voiceReleaseTimer)
    this.voiceReleaseTimer = window.setTimeout(() => {
      if (this.currentStatus !== "Planner is speaking…") return
      this.updateVoiceLevel(0)
      if (this.voiceLevel > 0) this.scheduleVoiceLevelRelease()
    }, 50)
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

  postForm(url, values) {
    return fetch(url, {
      method: "POST",
      headers: {
        "Accept": "text/html",
        "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
        "X-CSRF-Token": this.csrfToken()
      },
      body: new URLSearchParams(values),
      credentials: "same-origin"
    }).then((response) => {
      if (!response.ok) throw new Error("The spoken answer could not be saved. You can keep typing.")
      return response
    })
  }

  async replaceBuilder(response) {
    const currentFrame = this.hasCardStateTarget ? this.cardStateTarget.closest("turbo-frame") : null
    if (!currentFrame) return

    const document = new DOMParser().parseFromString(await response.text(), "text/html")
    const nextFrame = document.getElementById(currentFrame.id)
    if (nextFrame && currentFrame.isConnected) currentFrame.replaceWith(nextFrame)
  }

  requestWakeLock = () => {
    if (!this.active || document.visibilityState !== "visible" || this.wakeLock && !this.wakeLock.released) return

    navigator.wakeLock?.request("screen").then((wakeLock) => {
      if (this.active) {
        this.wakeLock = wakeLock
      } else {
        wakeLock.release().catch(() => {})
      }
    }).catch(() => {})
  }

  releaseWakeLock() {
    const wakeLock = this.wakeLock
    this.wakeLock = null
    wakeLock?.release().catch(() => {})
  }

  visibilityChanged = () => {
    if (document.visibilityState === "visible" && this.active) this.requestWakeLock()
  }

  stopConversation() {
    if (!this.active && !this.socket && !this.stream && !this.audioContext && !this.wakeLock) return

    this.active = false
    this.releaseWakeLock()
    this.closing = false
    this.responseActive = false
    this.responseDraining = false
    this.pendingIntro = false
    this.ackPending = false
    this.intentionalClose = true
    window.clearTimeout(this.voiceReleaseTimer)
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
    this.voiceLevel = 0
    delete this.element.dataset.voiceActive
    if (this.hasPanelTarget) this.panelTarget.hidden = true
    this.paintOrbs()
    this.updateLaunchers()
  }

  fail(message) {
    this.stopConversation()
    this.errorToastId = toast.error(message)
  }

  clearError() {
    if (this.errorToastId) toast.dismiss(this.errorToastId)
    this.errorToastId = null
  }

  updateLaunchers() {
    if (!this.hasLauncherTarget) return

    const phase = this.hasCardStateTarget ? this.cardStateTarget.dataset.voicePhase : null
    const unavailablePhase = [ "waiting", "error", "reviewing" ].includes(phase)
    this.launcherTargets.forEach((launcher) => {
      launcher.hidden = !this.supported || this.active || unavailablePhase
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
    this.currentStatus = status
    if ([ "Thinking…", "Adding to your plan…" ].includes(status)) this.voiceLevel = 0
    this.statusTargets.forEach((target) => { target.textContent = status })
    this.paintOrbs()
  }

  paintCaptions(fallback = null) {
    this.assistantCaptionTargets.forEach((target) => {
      target.textContent = this.assistantText || fallback || "Waiting to speak…"
    })
    this.userCaptionTargets.forEach((target) => {
      target.textContent = this.userText || "Listening…"
    })
    this.assistantCaptionTargets.forEach((target) => {
      const captions = target.closest(".voice-captions")
      if (captions) captions.scrollTop = captions.scrollHeight
    })
  }

  paintOrbs() {
    this.orbTargets.forEach((orb) => this.paintOrb(orb))
  }

  paintOrb(orb) {
    orb.style.setProperty("--voice-level", this.voiceLevel || 0)
    orb.classList.toggle("has-level", this.voiceLevel >= 0.03)
    orb.classList.toggle("is-speaking", this.currentStatus === "Planner is speaking…")
    orb.classList.toggle("is-thinking", [ "Thinking…", "Adding to your plan…" ].includes(this.currentStatus))
    orb.classList.toggle("is-listening", ![ "Planner is speaking…", "Thinking…", "Adding to your plan…" ].includes(this.currentStatus))
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  messageFor(error) {
    if (error?.name === "NotAllowedError") return "Microphone access was denied. You can keep typing."
    if (error instanceof TypeError) return "Voice planning lost its connection. You can keep typing."
    return error?.message || "Voice planning is unavailable. You can keep typing."
  }
}
