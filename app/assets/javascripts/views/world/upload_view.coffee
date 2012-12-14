#= require jquery.s3upload

class Application.WorldUploadView extends Backbone.View
  @maxFileSize: 1 * 1024 * 1024 * 1024 # 1 Gb

  initialize: ({@sign_url, @post_upload_url, @pusher_chan}) ->
    channel = window.pusher.subscribe(@pusher_chan)
    channel.bind 'update', (msg) =>
      @$('.processing-help-block .step').text("(#{msg})")

    channel.bind 'success', =>
      @$('.help-block').hide()
      @$('.progress').addClass('progress-success')
      @$('.success-help-block').show()
      window.location.reload()

    channel.bind 'error', @error
    

  events:
    'change input.upload': 'change'
    
  render: ->
    @$('.progress').hide()

  change: ->
    filename = @$('input[type=file]').val()
    
    new S3Upload
      s3_object_name: filename
      file_dom_selector: 'input.upload'
      s3_sign_put_url: @sign_url
      onProgress: @progress
      onFinishS3Put: @complete
      onError: @error
    
    @start(filename)

  unloadMsg = -> 'Your upload will be lost.'

  start: (filename) =>
    @$('.help-block').hide()
    @$('filename').text(filename)
    @$('input[type=file]').hide()
    @$('.progress').show().removeClass('progress-danger')
    
    $(window).on 'beforeunload', unloadMsg
    @trigger 'start'

  progress: (progress, info) =>
    @$('.progress .bar').css(width: "#{progress}%")
    false

  error: (msg) =>
    @$('input[type=file]').show()
    @$('.help-block').hide()
    @$('.error-help-block .reason').text(msg)
    @$('.error-help-block').show()
    @$('.progress').addClass('progress-danger')

    $(window).off 'beforeunload', unloadMsg

    @trigger 'error'

  retry: (e) =>
    e.preventDefault()
    @$('.progress').removeClass('progress-danger')
    @$('input[type=file]').show()

  complete: (url) =>
    @$('.help-block').hide()
    @$('.processing-help-block').show()

    $.ajax
      type: 'POST'
      url: @post_upload_url
      data:
        url: url