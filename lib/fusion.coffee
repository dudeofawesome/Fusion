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

        # TODO find installed build systems and list them in the build systems menu
        # https://atom.io/docs/api/v0.204.0/MenuManager#instance-add
        # atom.menu.add([{label: 'hello world'}])

    deactivate: ->
        @modalPanel.destroy()
        @subscriptions.dispose()
        @fusionView.destroy()

    serialize: ->
        fusionViewState: @fusionView.serialize()

    build: ->
        atom.notifications.addSuccess("Building...", {detail: 'using ' + 'build system'})

        # TODO add if test for settings
        atom.workspaceView.trigger("window:save-all")

        editor = atom.workspace.getActiveTextEditor()
        file = editor.getTitle()
        fileSplit = file.split('.')
        fileBaseName = fileSplit[0]
        fileType = fileSplit[fileSplit.length - 1];
        filePath = editor.getPath().split(file)[0]

        buildProcess = child_process.spawn 'echo', ['hello world']
        buildProcess.stdout.on 'data', (buffer) ->
            atom.notifications.addInfo('Build Result', {detail: '# ' + buffer})

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
        # editor = atom.workspace.getActiveTextEditor()
        # if (editor)
        #     editor.insertText('Canceling build...')
        atom.notifications.addInfo("Build Cancelled")

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
