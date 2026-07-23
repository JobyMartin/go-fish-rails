import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="rummy-turn"
export default class extends Controller {
  static targets = [
    "card",
    "meldCardIdsContainer", "meldButton",
    "discardCardId", "discardButton",
    "layoffCardId", "layoffButton"
  ]

  toggle(event) {
    event.currentTarget.classList.toggle("is-selected")
    this.sync()
  }

  sync() {
    const tokens = this.selectedTokens()

    this.syncMeldCardIds(tokens)
    this.syncSingleCardTargets(this.discardCardIdTargets, tokens)
    this.syncSingleCardTargets(this.layoffCardIdTargets, tokens)
    this.syncButtons(tokens)
  }

  selectedTokens() {
    return this.cardTargets
      .filter((card) => card.classList.contains("is-selected"))
      .map((card) => card.dataset.card)
  }

  syncMeldCardIds(tokens) {
    if (!this.hasMeldCardIdsContainerTarget) return

    this.meldCardIdsContainerTarget.innerHTML = ""
    tokens.forEach((token) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "play_turn[card_ids][]"
      input.value = token
      this.meldCardIdsContainerTarget.appendChild(input)
    })
  }

  syncSingleCardTargets(targets, tokens) {
    const value = tokens.length === 1 ? tokens[0] : ""
    targets.forEach((target) => { target.value = value })
  }

  syncButtons(tokens) {
    if (this.hasMeldButtonTarget) {
      this.meldButtonTarget.disabled = this.baseDisabled(this.meldButtonTarget) || tokens.length === 0
    }
    if (this.hasDiscardButtonTarget) {
      this.discardButtonTarget.disabled = this.baseDisabled(this.discardButtonTarget) || tokens.length !== 1
    }
    this.layoffButtonTargets.forEach((button) => {
      button.disabled = this.baseDisabled(button) || tokens.length !== 1
    })
  }

  baseDisabled(button) {
    return button.dataset.baseDisabled === "true"
  }
}
