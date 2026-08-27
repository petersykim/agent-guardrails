# The end-of-session letter

**An agent forgets everything between sessions, and the git log only carries what changed, never what mattered.**

A markdown template an agent fills in before its context clears, addressed to
whoever wakes up next. Not a task handoff, that part is already on disk.

## Install

Drop `LETTER-TEMPLATE.md` wherever session-end instructions live, and add one
line to them: before the context clears, write a letter against this template
and save it to a dated file.

Keep the letters in one folder. The next session reads the two most recent
before touching the task list.

## The four prompts

**What we did.** Two or three sentences on the shape of the work, not a
changelog.

**What broke.** Specific and unsoftened. A vague warning is worse than none.

**What I would do differently.** The thing learned too late to use. Usually the
highest-value line in the letter.

**What the human is actually worried about.** Not the ticket. The deadline, the
bill, the decision underneath it. Without this the next session rediscovers the
emotional context from scratch, which reads to the human like talking to a
stranger wearing a friend's face.

Plus a short "do not relitigate" list, so a fresh session does not spend an
hour reopening decisions that were already made.

## Why it works

The technical handoff is the easy half and could be generated from the git log.
The half that does not survive a reset any other way is the mood in the room
and the things not to bring up again.

## What to change

The prompts, to match what your sessions actually lose. Keep it short enough
that the next one reads it rather than skims it.

MIT.
