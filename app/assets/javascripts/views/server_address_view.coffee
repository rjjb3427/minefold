#= require models/server

class window.ServerAddressView extends Backbone.View
  model: Server

  events:
    'click input.server-address': 'click'

  initialize: ->
    @model.on('change:address', @render)

  render: =>
    connectBtn = @$('.btn.connect')
    address = @$('.server-address')

    if address.val()? and address.val() != ''
      address.popover()
      @$el.addClass('is-connectable')
      address.val(@model.get('address'))
      connectBtn.attr(href: @model.steamConnectUrl())
      connectBtn.show()

    else
      @$el.removeClass('is-connectable')
      address.val("No address")
      connectBtn.hide()

    if !@model.get('steamId')?
      connectBtn.hide()

  click: =>
    @$('.server-address').select()
