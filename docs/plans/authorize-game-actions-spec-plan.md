# Feature: Authorize game actions to participants

## Feature summary

Signed-in users may only view and act on games they are participants of. Today
`GamesController#show/start/play/winner` require authentication but never check
membership, so any signed-in user can read another game's state or `POST`
`start`/`play` against any game id. `show` for a non-participant is also a latent 500
(`find_player` → `nil`, then `current_player.hand` in the partial).

After this change, a signed-in **non-participant** who hits any of those four actions is
**redirected to the lobby (`games_path`) with the flash "You're not in that game."** and
never sees game content or mutates the game. **Participants are unaffected.** `join`
(`PlayersController#create`) is intentionally left open — joining is a non-participant
action by nature.

## Test coverage

### `spec/system/games_spec.rb` (modify existing)

A new `context 'when the user is not a participant'` — the inverse of the existing
participant setup: a `game` whose only `Player` belongs to `user2`, with `user` signed in
(the existing `before { sign_in(user) }` at the top already covers this).

#### when the user is not a participant
- [x] redirects to the lobby with a flash when visiting the game page (`show`)
- [x] does not show any game content on the redirect (no "Start game")
- [x] redirects to the lobby when visiting the winner screen (`winner`)

Coverage note (`start`/`play`): the four actions share one `before_action`
(`require_participation`, `only: %i[show start play winner]`). Proving the guard fires on
the two GET actions (`show`, `winner`) via system specs demonstrates the guard for all
four — the `POST` actions are protected by the same filter, in the same `only:` list.
Per project convention (system specs; request specs almost never used) we do **not** add
request specs for `start`/`play`.

## Related specs (regression check)

- `spec/system/games_spec.rb` — the existing participant happy-path contexts (`when they
  view a game they are in`, `when the user clicks to start a game`, `when the user plays a
  turn`, winner-screen contexts) must stay green — participants still get in.
- `spec/requests/` — none currently relevant; project convention is system specs.

## Implementation (after specs are red)

Two scoped `before_action`s in `GamesController`, matching the existing `Authentication`
concern shape:

- `set_game` — `@game = Game.find(params[:id])`, `only: %i[show start play winner]`; drop
  the four inline `Game.find` calls.
- `require_participation` — runs after `set_game`, same `only:`; if
  `@game.users.include?(Current.session.user)` is false,
  `redirect_to games_path, alert: "You're not in that game."`

Ordering: `set_game` → `require_participation` → action body. This is what makes the 500
fix work — `require_participation` short-circuits before `show` renders the partial.
