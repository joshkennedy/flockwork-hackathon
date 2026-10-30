# Voice planning sends the Leader's voice to xAI

Voice planning sends the Leader's raw microphone audio to xAI, so a name spoken aloud can reach a third party before Flockwork can redact it. Voice is opt-in for each Planner session, the interface tells Leaders to talk about the work rather than people, and typing always remains available. Flockwork builds voice instructions only from the Planner's safe ContextBuilder, then redacts directory names from every answer before storing it or sending it to the planning model. ADR 0002 still holds for everything Flockwork sends.
