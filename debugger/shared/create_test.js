$(function () {
    $('#add-command-button').on('click', function () {
        $('#new-command-panel').show()
    })
    $('#cancel-command-button').on('click', function () {
        $('#new-command-panel').hide()
    })
    $('#create-command-button').on('click', function () {
        const tbody = $('table.tests-table tbody')
        const row = $('<tr class="command"></tr>')
        const cells = {}
        $('.new-command-input').each(function () {
            const e = $(this)
            cells[parseInt(e.data('order'))] = e.val()
        })
        for (const [key, value] of Object.entries(cells)) {
            row.append($(`<td>${value}</td>`))
        }
        tbody.append(row)
        $('#new-command-panel').hide()
    })
    $('#create-test-form').on('submit', function (e) {
        e.preventDefault()
        $('#add-command-button').attr('disabled', true)
        $('#send-form-button').attr('disabled', true)
        const test_name = $('#test_name').val()
        const commands = []
        $('.command').each(function () {
            const row = $(this)
            let command_name = ""
            const values = []
            row.children('td').each(function (index, element) {
                const value = $(element).text()
                if (index == 0)
                    command_name = value
                else
                    values.push(parseInt(value))
            })
            commands.push({
                'name': command_name,
                'params': values,
            })
        })
        const result = {
            'name': test_name,
            'instructions': commands
        }
        fetch('/create-test', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(result)
        }).then(_ => location.assign('/'))
    })
})