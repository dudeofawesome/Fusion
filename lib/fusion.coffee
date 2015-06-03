FusionView = require './fusion-view'
{CompositeDisposable} = require 'atom'

child_process = require 'child_process'
FS = require 'fs'
CSON = require 'cson'

currentBuild = null
currentBuildSystem = null
buildSystems = []
switchBuildSystemFuncs = {}

module.exports = Fusion =
    fusionView: null
    modalPanel: null
    subscriptions: null
    config:
        selectedBuildSystem:
            type: 'string'
            default: 'Automatic'
        saveAllOnBuild:
            type: 'boolean'
            default: true

    menu: {}

    activate: (state) ->
        @fusionView = new FusionView(state.fusionViewState)
        @modalPanel = atom.workspace.addModalPanel(item: @fusionView.getElement(), visible: false)

        # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
        @subscriptions = new CompositeDisposable

        # Register command that toggles this view
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:build': => @build()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:run': => @run()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:switch-build-system-auto': => @switchBuildSystemAuto()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:new-build-system': => @newBuildSystem()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:choose-build-system': => @chooseBuildSystem()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:cancel-build': => @cancelBuild()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:show-build-results': => @showBuildResults()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:show-next-build-result': => @showNextBuildResult()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:show-previous-build-result': => @showPreviousBuildResult()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:save-all-on-build': => @saveAllOnBuild()

        this.getFusionMenu()
        this.updateListOfBuildSystems()

        for i of buildSystems
            if buildSystems[i].name is atom.config.get('fusion.selectedBuildSystem')
                currentBuildSystem = buildSystems[i]

        # TODO set save all on build menu option to current state

    deactivate: ->
        @modalPanel.destroy()
        @subscriptions.dispose()
        @fusionView.destroy()

    serialize: ->
        fusionViewState: @fusionView.serialize()

    build: ->
        editor = atom.workspace.getActiveTextEditor()
        file = editor.getTitle()
        fileSplit = file.split('.')
        fileBaseName = fileSplit[0]
        fileType = fileSplit[fileSplit.length - 1];
        filePath = editor.getPath().split(file)[0]

        if atom.config.get('fusion.selectedBuildSystem') is 'Automatic'
            for i of buildSystems
                for j of buildSystems[i].extensions
                    if buildSystems[i].extensions[j].includes(fileType)
                        currentBuildSystem = buildSystems[i]

        atom.notifications.addInfo('Building...', {detail: 'using ' + currentBuildSystem.name + ' build system' + if atom.config.get('fusion.selectedBuildSystem') is 'Automatic' then ' (Auto)' else ''})

        atom.workspaceView.trigger('window:save-all') if atom.config.get('fusion.saveAllOnBuild') is true

        filledArgs = currentBuildSystem.commandSequence[0].arguments.slice(0)
        for i of filledArgs
            filledArgs[i] = filledArgs[i].replace('{{file}}', file);
            filledArgs[i] = filledArgs[i].replace('{{file_base_name}}', fileBaseName);
            filledArgs[i] = filledArgs[i].replace('{{file_type}}', fileType);
            filledArgs[i] = filledArgs[i].replace('{{file_path}}', filePath);

        Fusion.menu.cancel.enabled = true

        currentBuild = child_process.spawn currentBuildSystem.commandSequence[0].command, filledArgs, {cwd: filePath}
        currentBuild.on 'close', (code) ->
            Fusion.menu.cancel.enabled = false
            atom.notifications.addSuccess('Build Finished', {detail: 'Finished with code ' + code})
        currentBuild.stdout.on 'data', (buffer) ->
            # TODO display build log
            console.log(buffer.toString())
        currentBuild.stderr.on 'data', (buffer) ->
            console.log(buffer.toString())
            atom.notifications.addError('Build Result', {detail: buffer})

    run: ->
        # TODO add run option
        Fusion.menu.cancel.enabled = true

    switchBuildSystemAuto: ->
        atom.config.set('fusion.selectedBuildSystem', 'Automatic')
        atom.notifications.addInfo('Switching build system', {detail: 'Switched to Auto'})

    newBuildSystem: ->
        editor = atom.workspace.getActiveTextEditor()
        if (editor)
            editor.insertText('New build system...')

    chooseBuildSystem: ->
        editor = atom.workspace.getActiveTextEditor()
        if (editor)
            editor.insertText('Choosing build system...')
        this.getInstalledBuildSystems()

    cancelBuild: ->
        if currentBuild
            currentBuild.kill()
            Fusion.menu.cancel.enabled = false
            atom.notifications.addInfo('Build Cancelled')

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
        # toggle fusion.save-all-on-build
        atom.config.set('fusion.saveAllOnBuild', !atom.config.get('fusion.saveAllOnBuild'))

    getFusionMenu: ->
        for i of atom.menu.template
            if atom.menu.template[i].label is "Packages"
                for j of atom.menu.template[i].submenu
                    if atom.menu.template[i].submenu[j].label is "Fusion"
                        Fusion.menu.parent = atom.menu.template[i].submenu[j]
                        Fusion.menu.buildSystems = atom.menu.template[i].submenu[j].submenu[0]
                        Fusion.menu.build = atom.menu.template[i].submenu[j].submenu[1]
                        Fusion.menu.run = atom.menu.template[i].submenu[j].submenu[2]
                        Fusion.menu.buildWith = atom.menu.template[i].submenu[j].submenu[3]
                        Fusion.menu.cancel = atom.menu.template[i].submenu[j].submenu[4]
                        Fusion.menu.buildResults = atom.menu.template[i].submenu[j].submenu[5]
                        Fusion.menu.saveAllOnBuild = atom.menu.template[i].submenu[j].submenu[6]

    getInstalledBuildSystems: ->
        # TODO get extended build systems
        installedBuildSystems = []
        installedBuildSystemsPath = atom.packages.resolvePackagePath('Fusion') + '/lib/build-systems/'
        installedBuildSystemsNames = FS.readdirSync(installedBuildSystemsPath)
        for i of installedBuildSystemsNames
            # console.log i + ":" + installedBuildSystemsNames[i]
            installedBuildSystems.push CSON.parse FS.readFileSync(installedBuildSystemsPath + installedBuildSystemsNames[i]).toString()

        # console.log(installedBuildSystems);

        return installedBuildSystems

    updateListOfBuildSystems: ->
        buildSystems = this.getInstalledBuildSystems()

        for i of buildSystems
            switchBuildSystemFuncs[buildSystems[i].name] = ((bs) ->
                return (->
                    currentBuildSystem = bs
                    atom.config.set('fusion.selectedBuildSystem', bs.name)
                    atom.notifications.addInfo('Switching build system', {detail: 'Switched to ' + bs.name})
                )
            )(buildSystems[i])
            @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:switch-build-system-' + buildSystems[i].name, switchBuildSystemFuncs[buildSystems[i].name]

            Fusion.menu.buildSystems.submenu.splice(Fusion.menu.buildSystems.submenu.length - 2, 0, {type: 'radio', label: buildSystems[i].name, command: 'fusion:switch-build-system-' + buildSystems[i].name, checked: (if atom.config.get('fusion.selectedBuildSystem') is buildSystems[i].name then true else false)})
        atom.menu.update()
