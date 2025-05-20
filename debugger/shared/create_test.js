function remove_command(element) {
    $(element).parents("tr").remove();
}

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
        number_base = parseInt($("#number-system").find(":selected").val())
        let r = /^[+-]?[0-9]+$/;
        if (number_base == 2) {
            r = /^[+-]?[01]+$/;
        } else if (number_base == 16) {
            r = /^[+-]?[0-9A-Fa-f]+$/;
        }
        let first = true;
        $('.new-command-input').each(function () {
            const e = $(this)
            let value = e.val()
            if (!first && !r.test(value)) {
                value = "0"
            }
            cells[parseInt(e.data('order'))] = value
            first = false;
        })
        first = true;
        for (const [key, value] of Object.entries(cells)) {
            if (first) {
                row.append($(`<td data-actualvalue='${value}'>${value}</td>`))
                first = false;
                continue;
            }
            const actualvalue = parseInt(value, number_base);
            row.append($(`<td class='diff-base' data-actualvalue='${actualvalue}'>${value}</td>`))
        }
        row.append($(`<td><button onclick="remove_command(this)">X</button></td>`))
        tbody.append(row)
        $('#new-command-panel').hide()
    })
    $('#create-test-form').on('submit', function (e) {
        e.preventDefault()
        const test_name = $('#test_name').val()
        const r = /[0-9A-Za-z_-]/;
        if ($('.command').length == 0 || !r.test(test_name)) {
            window.location.reload()
            return;
        }
        $('#add-command-button').attr('disabled', true)
        $('#send-form-button').attr('disabled', true)
        const commands = []
        $('.command').each(function () {
            const row = $(this)
            let command_name = ""
            const values = []
            row.children('td').each(function (index, element) {
                const value = $(element).data('actualvalue')
                if (index == 0)
                    command_name = value
                else if (index == row.children('td').length - 1)
                    return
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
    $('#number-system').on('change', function() {
        number_base = $(this).find(":selected").val();
        $("td.diff-base").each(function() {
            const actualvalue = $(this).data('actualvalue');
            $(this).text(parseInt(actualvalue).toString(parseInt(number_base)));
        });
    })
})