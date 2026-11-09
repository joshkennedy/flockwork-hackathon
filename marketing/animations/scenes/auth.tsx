import { SignupScene } from './card-signup'

// The panel beside the sign-in and sign-up forms: the card's public sign-up story, larger,
// so the auth pages show what people are signing in to.
export default function Auth() {
  return <SignupScene width={600} height={820} phone={390} className="fw-auth" />
}

export const meta = { out: 'auth', seconds: 7, poster: 3000 }
