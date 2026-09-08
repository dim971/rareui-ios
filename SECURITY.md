# Security policy

## Supported versions

This library is pre-1.0. Fixes land on `main` and go out in the next tagged
release; there are no maintained branches for older tags yet.

## Reporting a vulnerability

Please **do not** open a public issue for a security problem.

Use GitHub's private reporting instead: go to the **Security** tab of this
repository and choose **Report a vulnerability**. That opens a private advisory
visible only to the maintainers.

Please include what you were doing, what happened, and how to reproduce it. You
can expect an acknowledgement within a few days, and to be kept informed until
it is resolved.

## Scope

This is a component library with no persistence, no credentials and no
dependencies. It has one deliberate exception: `GitHubActivity` can fetch a
contribution grid from a public API when you give it a username, and
`GridReveal` loads an image you point it at. Both are opt-in, both take URLs
from the caller, and neither sends anything anywhere. Everything else draws
and animates locally.

The plausible surface is therefore small: input that makes a component
misbehave, a size, a count or a colour that causes a crash, a hang, a runaway
animation loop or unbounded memory use. Those are worth reporting, as is
anything the two networked components do with a response that you would not
expect.
