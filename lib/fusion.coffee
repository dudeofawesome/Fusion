FusionView = require './fusion-view'
{CompositeDisposable} = require 'atom'

child_process = require 'child_process'
fs = require 'fs'
currentBuild = null

module.exports = Fusion =
    fusionView: null
    modalPanel: null
    subscriptions: null

    activate: (state) ->
        @fusionView = new FusionView(state.fusionViewState)
        @modalPanel = atom.workspace.addModalPanel(item: @fusionView.getElement(), visible: false)

        # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
        @subscriptions = new CompositeDisposable

        # Register command that toggles this view
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:build': => @build()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:run': => @run()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:switch-build-system': => @switchBuildSystem()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:new-build-system': => @newBuildSystem()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:choose-build-system': => @chooseBuildSystem()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:cancel-build': => @cancelBuild()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:show-build-results': => @showBuildResults()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:show-next-build-result': => @showNextBuildResult()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:show-previous-build-result': => @showPreviousBuildResult()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:save-all-on-build': => @saveAllOnBuild()

    deactivate: ->
        @modalPanel.destroy()
        @subscriptions.dispose()
        @fusionView.destroy()

    serialize: ->
        fusionViewState: @fusionView.serialize()

    build: ->
        editor = atom.workspace.getActiveTextEditor()
        if (editor)
            editor.insertText('Building...')

    run: ->
        editor = atom.workspace.getActiveTextEditor()
        if (editor)
            editor.insertText('Running...')

    switchBuildSystem: ->
        editor = atom.workspace.getActiveTextEditor()
        if (editor)
            editor.insertText('Switching build system...')

    newBuildSystem: ->
        editor = atom.workspace.getActiveTextEditor()
        if (editor)
            editor.insertText('New build system...')

    chooseBuildSystem: ->
        editor = atom.workspace.getActiveTextEditor()
        if (editor)
            editor.insertText('Choosing build system...')

    cancelBuild: ->
        editor = atom.workspace.getActiveTextEditor()
        if (editor)
            editor.insertText('Canceling build...')

    showBuildResults: ->
        editor = atom.workspace.getActiveTextEditor()
        if (editor)
            editor.insertText('Showing build results...')

    showNextBuildResult: ->
        editor = atom.workspace.getActiveTextEditor()
        if (editor)
            editor.insertText('Showing next build result...')

    showPreviousBuildResult: ->
        editor = atom.workspace.getActiveTextEditor()
        if (editor)
            editor.insertText('Showing previous build result...')

    saveAllOnBuild: ->
        editor = atom.workspace.getActiveTextEditor()
        if (editor)
            editor.insertText('Save all on build...')
