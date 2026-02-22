import WikiToolbarController from "controllers/wiki_toolbar_controller"

export default class extends WikiToolbarController {
    strong() {
        this.singleTag('*')
    }

    italic() {
        this.singleTag('_')
    }

    underline() {
        this.singleTag('+')
    }

    deleted() {
        this.singleTag('-')
    }

    inlineCode() {
        this.singleTag('@')
    }

    h1() {
        this.encloseLineSelection('h1. ', '', (str) => {
            return str.replace(/^h\d+\.\s+/, '')
        })
    }

    h2() {
        this.encloseLineSelection('h2. ', '', (str) => {
            return str.replace(/^h\d+\.\s+/, '')
        })
    }

    h3() {
        this.encloseLineSelection('h3. ', '', (str) => {
            return str.replace(/^h\d+\.\s+/, '')
        })
    }

    unorderedList() {
        this.encloseLineSelection('', '', (str) => {
            str = str.replace(/\r/g, '')
            return str.replace(/(\n|^)[#-]?\s*/g, "$1* ")
        })
    }

    orderedList() {
        this.encloseLineSelection('', '', (str) => {
            str = str.replace(/\r/g, '')
            return str.replace(/(\n|^)[*-]?\s*/g, "$1# ")
        })
    }

    quote() {
        this.encloseLineSelection('', '', (str) => {
            str = str.replace(/\r/g, '')
            return str.replace(/(\n|^)( *)([^\n]*)/g, "$1> $2$3")
        })
    }

    unquote() {
        this.encloseLineSelection('', '', (str) => {
            str = str.replace(/\r/g, '')
            return str.replace(/(\n|^) *(> ?)?( *)([^\n]*)/g, "$1$3$4")
        })
    }

    pre() {
        this.encloseLineSelection('<pre>\n', '\n</pre>')
    }

    image() {
        this.encloseSelection("!", "!")
    }

    insertTable(cols, rows) {
        const alphabets = "ABCDEFGHIJ".split('')
        const header = '|_.' + alphabets.slice(0, cols).join('|_.') + '|\n'
        const cells = Array(rows + 1).join(Array(cols + 1).join('|  ') + '|\n')
        this.encloseLineSelection(header + cells, '')
    }

    insertPrecode(lang) {
        this.encloseLineSelection('<pre><code class="' + lang + '">\n', '\n</code></pre>\n')
    }
}
