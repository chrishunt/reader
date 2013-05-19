App.ITEM_SET_SIZE = 10
App.filter = 'unread'

App.stream = null

# TODO: hook this into settings; persist the value, read from DB
App.showAllSubscriptions = false

App.filterFunction = (item) ->
  (App.filter == 'all' || (item.get(App.filter) == true))

App.$doc = $(document)

App.boot = ->
  App.comments = new App.Comments
  App.people = new App.People
  App.groups = new App.Groups
  App.counts = new App.Counts

  App.updateTopStreamCounts()

  App.createTemplates()
  App.setupStreamMenu()
  App.on("item:save", _.throttle(App.updateTopStreamCounts, 100))

  App.$doc.scroll(_.throttle(App.scrollWatch, 100))
  App.on "change:filter", () ->
    App.highlightNavByFilter()
    App.renderFeedList()

  App.updateTooltips()

  new App.SubscriptionCountUpdate

#  $("#summary-container").load("/summary")

App.highlightNavByFilter = ->
  $(".nav-icon").removeClass("current")
  switch App.filter
    when "unread" then $("#nav-unread-link").addClass("current")
    when "starred" then $("#nav-starred-link").addClass("current")
    when "shared" then $("#nav-shared-link").addClass("current")
    when "commented" then $("#nav-comments-link").addClass("current")
    when "all" then $("#nav-all-link").addClass("current")

App.highlightStreamInFeedList = ->
  $('li.li-group, li.li-subscription, li.li-person').removeClass("current")
  App.stream?.renderer?.$el?.addClass("current")
  unless App.stream?.getGroup?().get("open") == true
    App.stream?.getGroup?().renderer?.$el?.addClass("current")




App.scrollWatch = ->
  _(App.itemRenderers).each (ir) ->
    ir.checkScroll()

App.startRouter = () ->
  unless App.router?
    App.router = new App.Router()
    Backbone.history.start({pushState: true})

App.booted = ->
  App.updateGroupCounts()
  App.updateSubscriptionCounts()
  App.updatePersonCounts()
  App.ready = true
  App.setupDropTargets()
  App.topGroup = App.groups.find (grp) ->
    (grp.get('key') == '')

App.updateTopStreamCounts = ->
  $.ajax
    url: "/items/counts.json",
    success: (data, status, xhr) ->
      App.counts.set(data)
      if data.has_new_comments_count > 0
        $("#nav-comments-link").addClass("attention")
      else
        $("#nav-comments-link").removeClass("attention")

App.updateSubscriptionCounts = ->
  subs = App.subscriptions
  subs.each (sub) ->
    sub.updateCount()

App.updatePersonCounts = ->
  people = App.people
  people.each (person) ->
    person.updateCount()

App.updateGroupCounts = ->
  groups = App.groups
  groups.each (group) ->
    group.updateCount()





App.streamMenu = null
App.setupStreamMenu = ->
  _view = new App.StreamMenuView
    el: $('#stream-menu-container')
  App.streamMenu = _view

App.setupDropTargets = ->
  $('#feed-list').sortable
    connectWith: '.feed-list'
    stop: (evt, ui) ->
      $item = ui.item.first()
      grp = App.groups.get $item.find('.li-group').first().data("id")
      prev = grp.prev()
      next = grp.next()
      if prev?
        grp.set('weight', prev.get("weight") + 1)
      else if next?
        grp.set('weight', next.get("weight") - 1)
      grp.save()
      App.renderFeedList()


  $('.group-list-drop-target').sortable
    connectWith: '.group-list-drop-target'
    stop: (evt, ui) ->
      $item = ui.item.first()
      group = App.groups.get $item.closest('.group-list-drop-target').first().attr('data-id')
      sub = App.subscriptions.get $item.attr('data-id')
      prev = sub.prev()
      next = sub.next()
      console.log "prev - #{prev.get("name")}" if prev?
      console.log "sub - #{sub.get("name")}" if sub?
      console.log "next - #{next.get("name")}" if next?
      if prev and prev.get("group_id") == sub.get("group_id")
        sub.set('weight', (prev.get("weight") - 1))
      else if next and next.get("group_id") == sub.get("group_id")
        sub.set('weight', (next.get("weight") + 1))
      sub.set('group_id', group.id)
      sub.fastSave()
      App.renderFeedList()

$(document).ready () ->
  tracker.track("Application load");
  _.extend(App, Backbone.Events)



