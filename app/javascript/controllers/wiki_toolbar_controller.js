import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"

export default class extends Controller {

  static targets = ["field", "previewPane", "editPane", "editTab", "previewTab", "buttons"]
  static values = {
    languages: Array,
    previewUrl: String,
    helpUrl: String
  }

  static lastPreviewed = null;

  connect() {
    this.field = this.hasFieldTarget ? this.fieldTarget : document.getElementById(this.element.dataset.fieldId)
    if (!this.field) return
  }

  strong() {
    // abstract
  }

  italic() {
    // abstract
  }

  underline() {
    // abstract
  }

  deleted() {
    // abstract
  }

  inlineCode() {
    // abstract
  }

  h1() {
    // abstract
  }

  h2() {
    // abstract
  }

  h3() {
    // abstract
  }

  unorderedList() {
    // abstract
  }

  orderedList() {
    // abstract
  }

  quote() {
    // abstract
  }

  unquote() {
    // abstract
  }

  pre() {
    // abstract
  }

  help() {
    window.open(this.helpUrlValue, "_blank")
  }

  precode(event) {
    event.preventDefault()
    this.precodeMenu(event.currentTarget)
  }

  table(event) {
    event.preventDefault()
    this.tableMenu(event.currentTarget)
  }

  wikiLink() {
    this.encloseSelection("[[", "]]")
  }

  image() {
    // abstract
  }

  // Common text manipulation methods
  singleTag(startTag, endTag) {
    endTag = endTag || startTag
    this.encloseSelection(startTag, endTag)
  }

  encloseSelection(prefix, suffix, fn) {
    this.field.focus()
    prefix = prefix || ''
    suffix = suffix || ''

    let start = this.field.selectionStart
    let end = this.field.selectionEnd
    let scrollPos = this.field.scrollTop
    let sel = this.field.value.substring(start, end)
    let subst

    if (start > 0 && this.field.value.charAt(start - 1).match(/\S/)) {
      prefix = ' ' + prefix
    }
    if (this.field.value.charAt(end).match(/\S/)) {
      suffix = suffix + ' '
    }

    if (sel.match(/ $/)) {
      sel = sel.substring(0, sel.length - 1)
      suffix = suffix + " "
    }

    let res = (typeof fn === 'function') ? ((sel) ? fn.call(this, sel) : fn('')) : (sel ? sel : '')
    subst = prefix + res + suffix

    this.field.setRangeText(subst, start, end, 'select')
    this.field.selectionStart = start + prefix.length
    this.field.selectionEnd = start + prefix.length + res.length
    this.field.scrollTop = scrollPos
  }

  encloseLineSelection(prefix, suffix, fn) {
    this.field.focus()
    prefix = prefix || ''
    suffix = suffix || ''

    let start = this.field.selectionStart
    let end = this.field.selectionEnd
    let scrollPos = this.field.scrollTop

    // Go to start of line
    while (start > 0 && this.field.value.charAt(start - 1) !== '\n' && this.field.value.charAt(start - 1) !== '\r') {
      start--
    }

    // Go to end of line
    while (end < this.field.value.length && this.field.value.charAt(end) !== '\n' && this.field.value.charAt(end) !== '\r') {
      end++
    }

    let sel = this.field.value.substring(start, end)
    if (sel.match(/ $/)) {
      sel = sel.substring(0, sel.length - 1)
      suffix = suffix + " "
    }

    let res = (typeof fn === 'function') ? ((sel) ? fn.call(this, sel) : fn('')) : (sel ? sel : '')
    let subst = prefix + res + suffix

    this.field.setRangeText(subst, start, end, 'select')
    this.field.selectionStart = start + prefix.length
    this.field.selectionEnd = start + prefix.length + res.length
    this.field.scrollTop = scrollPos
  }

  async preview(event) {
    event.preventDefault()
    const previewTab = event.currentTarget
    if (previewTab.classList.contains('selected')) return

    const formData = new FormData()
    formData.append('text', this.field.value)
    const form = this.field.closest('form')
    const attachmentInputs = form.querySelectorAll('.attachments_fields input');

    attachmentInputs.forEach(input => {
      if (input.name && input.value) {
        formData.append(input.name, input.value);
      }
    });

    try {
      const response = await post(this.previewUrlValue, {
        body: formData
      })
      if (response.ok) {
        const html = await response.text
        this.showPreview(html)
      }
    } catch (error) {
      console.error("Preview failed", error)
    }
  }

  edit(event) {
    event.preventDefault()
    const editTab = event.currentTarget
    if (editTab.classList.contains('selected')) return

    this.hidePreview(editTab)
  }

  togglePreview(event) {
    if (this.constructor.lastPreviewed !== null) {
      this.constructor.lastPreviewed.hidePreview()
      this.constructor.lastPreviewed = null
    }
  }

  showPreview(html) {
    // Find or create preview div
    this.previewPaneTarget.innerHTML = html
    this.editPaneTarget.classList.add('hidden')
    this.previewPaneTarget.classList.remove('hidden')
    this.editTabTarget.classList.remove('selected')
    this.previewTabTarget.classList.add('selected')
    this.buttonsTarget.classList.add('hidden')
    this.constructor.lastPreviewed = this;
  }

  hidePreview(editTab) {
    this.editPaneTarget.classList.remove('hidden')
    this.previewPaneTarget.classList.add('hidden')
    this.editTabTarget.classList.add('selected')
    this.previewTabTarget.classList.remove('selected')
    this.buttonsTarget.classList.remove('hidden')
  }

  tableMenu(button) {
    if (this.menu) {
      this.menu.remove()
      this.menu = null
      return
    }

    const alphabets = "ABCDEFGHIJ".split('')
    const menu = document.createElement('table')
    menu.className = 'table-generator'
    this.menu = menu

    for (let r = 1; r <= 5; r++) {
      const row = document.createElement('tr')
      for (let c = 1; c <= 10; c++) {
        const cell = document.createElement('td')
        cell.dataset.row = r
        cell.dataset.col = c
        cell.title = `${c}×${r}`

        cell.addEventListener('mousedown', (e) => {
          e.preventDefault()
          this.insertTable(c, r)
          this.menu.remove()
          this.menu = null
        })

        cell.addEventListener('mouseenter', () => {
          const cells = menu.querySelectorAll('td')
          cells.forEach(el => {
            if (parseInt(el.dataset.row) <= r && parseInt(el.dataset.col) <= c) {
              el.classList.add('selected-cell')
            } else {
              el.classList.remove('selected-cell')
            }
          })
        })

        row.appendChild(cell)
      }
      menu.appendChild(row)
    }

    document.body.appendChild(menu)

    // Positioning
    const rect = button.getBoundingClientRect()
    menu.style.left = `${rect.left + window.scrollX}px`
    menu.style.top = `${rect.bottom + window.scrollY}px`

    const closeMenu = (e) => {
      if (this.menu && !this.menu.contains(e.target) && e.target !== button && !button.contains(e.target)) {
        this.menu.remove()
        this.menu = null
        document.removeEventListener('mousedown', closeMenu)
      }
    }
    document.addEventListener('mousedown', closeMenu)
  }

  insertTable(cols, rows) {
    // abstract
  }

  precodeMenu(button) {
    if (this.menu) {
      this.menu.remove()
      this.menu = null
      return
    }

    const menu = document.createElement('ul')
    menu.className = 'drdn-items'
    menu.style.position = 'absolute'
    menu.style.zIndex = '1000'
    menu.style.backgroundColor = '#fff'
    menu.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.15)'
    menu.style.border = '1px solid #d7d7d7'
    menu.style.listStyle = 'none'
    menu.style.padding = '5px 0'
    menu.style.margin = '0'
    menu.style.minWidth = '150px'
    menu.style.maxHeight = '300px'
    menu.style.overflowY = 'auto'

    this.menu = menu

    this.languagesValue.forEach(lang => {
      const item = document.createElement('li')
      const link = document.createElement('a')
      link.href = '#'
      link.textContent = lang
      link.style.display = 'block'
      link.style.padding = '4px 12px'
      link.style.color = '#333'
      link.style.textDecoration = 'none'
      link.style.fontSize = '0.9em'

      link.addEventListener('mouseenter', () => {
        link.style.backgroundColor = '#3e70ad'
        link.style.color = '#fff'
      })
      link.addEventListener('mouseleave', () => {
        link.style.backgroundColor = 'transparent'
        link.style.color = '#333'
      })

      link.addEventListener('mousedown', (e) => {
        e.preventDefault()
        this.insertPrecode(lang)
        this.menu.remove()
        this.menu = null
      })

      item.appendChild(link)
      menu.appendChild(item)
    })

    document.body.appendChild(menu)

    // Positioning
    const rect = button.getBoundingClientRect()
    menu.style.left = `${rect.left + window.scrollX}px`
    menu.style.top = `${rect.bottom + window.scrollY}px`

    const closeMenu = (e) => {
      if (this.menu && !this.menu.contains(e.target) && e.target !== button && !button.contains(e.target)) {
        this.menu.remove()
        this.menu = null
        document.removeEventListener('mousedown', closeMenu)
      }
    }
    document.addEventListener('mousedown', closeMenu)
  }

  insertPrecode(lang) {
    // abstract
  }
}
