function divideIntoLines(input) {
    const maxLength = 16;
    let result = '';

    for (let i = 0; i < input.length; i += maxLength) {
        result += input.slice(i, i + maxLength) + '\n';
    }

    // Remove the trailing newline character if present
    if (result.endsWith('\n')) {
        result = result.slice(0, -1);
    }

    return result;
}

function toBinary(number, bitSize) {
    if (number >= 0) {
        const binary = number.toString(2).padStart(bitSize, '0');
        return divideIntoLines(binary);
    } else {
        const positiveBinary = Math.abs(number).toString(2).padStart(bitSize, '0');
        let invertedBinary = '';
        for (let bit of positiveBinary) {
            invertedBinary += bit === '0' ? '1' : '0';
        }
        let carry = 1;
        let twosComplement = '';
        for (let i = invertedBinary.length - 1; i >= 0; i--) {
            const sum = parseInt(invertedBinary[i]) + carry;
            twosComplement = (sum % 2).toString() + twosComplement;
            carry = Math.floor(sum / 2);
        }
        return divideIntoLines(twosComplement);
    }
}

function edittestcommand(testname, command_index, command_name, params) {
    $('#change_command_test').val(testname);
    $('#change_command_index').val(command_index);
    $('#command_name').val(command_name);
    number_base = parseInt($("#number-system").find(":selected").val())
    $('.new-command-input').each(function () {
        const order = parseInt($(this).data('order'))
        if (order != 0) {
            value = number_base == 2 ? toBinary(params[order - 1] + 0, $(this).data('binarybits')) : params[order - 1]
            $(this).val(value)
        }
    })
    $('#new-command-panel').show()
}

function sendeditcommand() {
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
    let new_name = command_name;
    let params = [];
    for (const [key, value] of Object.entries(cells)) {
        if (first) {
            new_name = value
            first = false;
            continue;
        }
        const actualvalue = parseInt(value, number_base);
        params.push(actualvalue)
    }
    result = {
        "test": $('#change_command_test').val(),
        "index": parseInt($('#change_command_index').val()),
        "name": new_name,
        "params": params,
    };
    fetch('/edit-command', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(result)
    }).then(_ => location.assign('/'))
}

function update_state() {
    fetch('/state').then(response => response.json()).then(data => {
        if (data.log !== undefined) {
            $('#log').html("");
            data.log.forEach(element => {
                $('#log').append($(`<p>${element}</p>`));
            });
        }
        if (data.tick !== undefined) {
            $('input#tick').val(data.tick);
        }
        if (data.selected_test !== undefined &&
            data.selected_test !== "" &&
            data.selected_instruction !== undefined) {
            show_test($(`.tablinks[data-tab=${data.selected_test}]`)[0], false);
            $('.tabcontent').removeClass("selected");
            $(`tr.tabcontent.${data.selected_test}`).each(function (index, element) {
                if (index == data.selected_instruction)
                    $(element).addClass("selected");
            })
        }
        number_base = $("#number-system").find(":selected").val();
        if (data.inputs_values !== undefined) {
            for (const [name, value] of Object.entries(data.inputs_values)) {
                let resultvalue = parseInt(value).toString(parseInt(number_base));
                if (parseInt(number_base) == 2) {
                    resultvalue = toBinary(parseInt(value), parseInt($(`#input-${name}`).data('binarybits')));
                }
                $(`#input-${name}`).val(resultvalue).data('actualvalue', value);
            }
        }
        if (data.outputs_values !== undefined) {
            for (const [name, value] of Object.entries(data.outputs_values)) {
                let resultvalue = parseInt(value).toString(parseInt(number_base));
                if (parseInt(number_base) == 2) {
                    resultvalue = toBinary(parseInt(value), parseInt($(`#output-${name}`).data('binarybits')));
                }
                $(`#output-${name}`).val(resultvalue).data('actualvalue', value);
            }
        }
        if (data.running !== undefined) {
            if (data.running === 1) {
                $("#run-button").hide();
                $("#step-button").hide();
                $("#reset-button").hide();
                $("#running-button").show();
            } else {
                $("#run-button").show();
                $("#step-button").show();
                $("#reset-button").show();
                $("#running-button").hide();
            }
        }
    }).catch(error => {
        alert(error);
    });
}

function show_test(button, do_update = true) {
    if (do_update)
        update_state();
    const tab = $(button).data("tab");
    $('.tabcontent').hide();
    $('.tablinks').removeClass("selected");
    $(button).addClass("selected");
    $(`.${tab}`).show();
}

$(function () {
    $('.input-file input[type=file]').on('change', function () {
        let file = this.files[0];
        $(this).closest('.input-file').find('.input-file-text').html(file.name);
    });
    $('.tabcontent').hide();
    $('.tablinks').on('click', function () {
        show_test(this);
    });
    $('#load-module-button').on("click", function () {
        fetch("/clear-module");
        window.location.reload();
    });
    $('#reset-button').on('click', function () {
        fetch("/reset-state").then(_ => location.assign('/'));
    });
    $('#run-button').on('click', function () {
        const test = $('.tablinks.selected').data('tab');
        fetch("/run?test=" + test).then(_ => update_state());
    });
    $('#step-button').on('click', function () {
        const test = $('.tablinks.selected').data('tab');
        fetch("/step?test=" + test).then(_ => update_state());
    });
    if ($('input#state').val() == "read_state") {
        setTimeout(update_state, 1000);
    }
    $('#number-system').on('change', function () {
        number_base = $(this).find(":selected").val();
        $("input.diff-base").each(function () {
            const actualvalue = $(this).data('actualvalue');
            let resultvalue = parseInt(actualvalue).toString(parseInt(number_base));
            if (parseInt(number_base) == 2) {
                resultvalue = toBinary(parseInt(actualvalue), parseInt($(this).data('binarybits')));
            }
            $(this).val(resultvalue);
        });
        $("td.diff-base").each(function () {
            const actualvalue = $(this).data('actualvalue');
            let resultvalue = parseInt(actualvalue).toString(parseInt(number_base));
            if (parseInt(number_base) == 2 && $(this).data('binarybits') !== undefined) {
                resultvalue = toBinary(parseInt(actualvalue), parseInt($(this).data('binarybits')));
            }
            $(this).text(resultvalue);
        });
    })
});