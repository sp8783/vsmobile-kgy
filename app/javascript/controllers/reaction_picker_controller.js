import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["picker"]
  static values = { matchId: Number, userId: Number }

  connect() {
    // Close picker when clicking outside
    this.boundCloseOnClickOutside = this.closeOnClickOutside.bind(this)
    document.addEventListener('click', this.boundCloseOnClickOutside)

    // Store current user's reactions locally
    this.myReactions = new Set()
    this.loadMyReactions()

    // Use MutationObserver to detect when elements are replaced (e.g., by broadcasts)
    this.observer = new MutationObserver(this.handleMutations.bind(this))
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  disconnect() {
    document.removeEventListener('click', this.boundCloseOnClickOutside)
    this.observer?.disconnect()
  }

  // Load current user's reactions from data attributes
  loadMyReactions() {
    this.element.querySelectorAll('.reaction-button-wrapper[data-my-reaction="true"]').forEach(wrapper => {
      const emojiId = wrapper.dataset.emojiId
      if (emojiId) {
        this.myReactions.add(emojiId)
      }
    })
  }

  // Track when user clicks a reaction
  trackReaction(event) {
    let emojiId = null

    // Check if clicked from reaction button wrapper
    const wrapper = event.target.closest('.reaction-button-wrapper')
    if (wrapper) {
      emojiId = wrapper.dataset.emojiId
    }

    // Check if clicked from picker button
    const pickerButton = event.target.closest('[data-emoji-id]')
    if (!emojiId && pickerButton) {
      emojiId = pickerButton.dataset.emojiId
    }

    if (emojiId) {
      if (this.myReactions.has(emojiId)) {
        this.myReactions.delete(emojiId)
      } else {
        this.myReactions.add(emojiId)
      }
    }
  }

  // Handle DOM mutations to restore highlight state after Turbo Stream replacements
  handleMutations(mutations) {
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.nodeType !== Node.ELEMENT_NODE) continue

        if (node.classList?.contains('reaction-button-wrapper')) {
          this.restoreHighlightForWrapper(node)
        }
        node.querySelectorAll?.('.reaction-button-wrapper')?.forEach(wrapper => {
          this.restoreHighlightForWrapper(wrapper)
        })
      }
    }
  }

  // Restore highlight for a single wrapper element
  restoreHighlightForWrapper(wrapper) {
    const emojiId = wrapper.dataset.emojiId
    const button = wrapper.querySelector('.reaction-button')
    if (!button || !emojiId) return

    if (this.myReactions.has(emojiId)) {
      // 自分がリアクション済み → 青いハイライト
      button.classList.remove('bg-gray-100', 'border', 'border-gray-200', 'hover:bg-gray-200', 'text-gray-700')
      button.classList.add('bg-blue-100', 'border-2', 'border-blue-400', 'text-blue-700')
      wrapper.dataset.myReaction = 'true'
    } else {
      // 自分はリアクションしていない → グレー（デフォルト）
      button.classList.remove('bg-blue-100', 'border-2', 'border-blue-400', 'text-blue-700')
      button.classList.add('bg-gray-100', 'border', 'border-gray-200', 'text-gray-700', 'hover:bg-gray-200')
      wrapper.dataset.myReaction = 'false'
    }
  }

  togglePicker(event) {
    event.stopPropagation()
    if (this.hasPickerTarget) {
      this.pickerTarget.classList.toggle('hidden')

      // Position the picker within viewport
      if (!this.pickerTarget.classList.contains('hidden')) {
        const barRect = this.element.getBoundingClientRect()
        const pickerRect = this.pickerTarget.getBoundingClientRect()

        // Default: right-aligned. If it overflows left, switch to left-aligned.
        if (barRect.right - pickerRect.width < 0) {
          this.pickerTarget.style.right = 'auto'
          this.pickerTarget.style.left = '0'
        } else {
          this.pickerTarget.style.right = '0'
          this.pickerTarget.style.left = 'auto'
        }
      }
    }
  }

  closePicker() {
    if (this.hasPickerTarget) {
      this.pickerTarget.classList.add('hidden')
    }
  }

  closeOnClickOutside(event) {
    if (this.hasPickerTarget && !this.element.contains(event.target)) {
      this.closePicker()
    }
  }
}
