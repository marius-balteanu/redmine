import WikiToolbarController from "controllers/wiki_toolbar_controller"

export default class extends WikiToolbarController {
    strong() {
        this.singleTag('**')
    }

    italic() {
        this.singleTag('*')
    }

    underline() {
        this.singleTag('<u>', '</u>')
    }

    deleted() {
        this.singleTag('~~')
    }

    inlineCode() {
        this.singleTag('`')
    }

    h1() {
        this.encloseLineSelection('# ', '', (str) => {
            return str.replace(/^#+\s+/, '')
        })
    }

    h2() {
        this.encloseLineSelection('## ', '', (str) => {
            return str.replace(/^#+\s+/, '')
        })
    }

    h3() {
        this.encloseLineSelection('### ', '', (str) => {
            return str.replace(/^#+\s+/, '')
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
            return str.replace(/(\n|^)[*-]?\s*/g, "$11. ")
        })
    }

    taskList() {
        this.encloseLineSelection('', '', (str) => {
            str = str.replace(/\r/g, '')
            return str.replace(/(\n|^)[*-]?\s*/g, "$1* [ ] ")
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
        this.encloseLineSelection('```\n', '\n```')
    }

    image() {
        this.encloseSelection("![](", ")")
    }

    insertTable(cols, rows) {
        const alphabets = "ABCDEFGHIJ".split('')
        const header = '|' + alphabets.slice(0, cols).join(' |') + ' |\n'
        const separator = Array(cols + 1).join('|--') + '|\n'
        const cells = Array(rows + 1).join(Array(cols + 1).join('|  ') + '|\n')
        this.encloseLineSelection(header + separator + cells, '')
    }

    insertPrecode(lang) {
        this.encloseLineSelection('``` ' + lang + '\n', '\n```\n')
    }
}
