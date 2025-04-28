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
            $(`tr.tabcontent.${data.selected_test}`).each(function(index, element) {
                if (index == data.selected_instruction)
                    $(element).addClass("selected");
            })
        }
        if (data.inputs_values !== undefined) {
            for (const [name, value] of Object.entries(data.inputs_values)) {
                $(`#input-${name}`).val(value);
            }
        }
        if (data.outputs_values !== undefined) {
            for (const [name, value] of Object.entries(data.outputs_values)) {
                $(`#output-${name}`).val(value);
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
    $('.input-file input[type=file]').on('change', function(){
        let file = this.files[0];
        $(this).closest('.input-file').find('.input-file-text').html(file.name);
    });
    $('.tabcontent').hide();
    $('.tablinks').on('click', function() {
        show_test(this);
    });
    $('#load-module-button').on("click", function() {
        fetch("/clear-module");
        window.location.reload();
    });
    $('#reset-button').on('click', function() {
        fetch("/reset-state").then(_ => location.assign('/'));
    });
    $('#run-button').on('click', function() {
        const test = $('.tablinks.selected').data('tab');
        fetch("/run?test=" + test).then(_ => update_state());
    });
    $('#step-button').on('click', function() {
        const test = $('.tablinks.selected').data('tab');
        fetch("/step?test=" + test).then(_ => update_state());
    });
    if ($('input#state').val() == "read_state") {
        setTimeout(update_state, 1000);
    }
});