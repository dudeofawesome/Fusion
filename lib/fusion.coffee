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
        # TODO get the panel working for showing build results
        # @modalPanel = atom.workspace.addBottomPanel (item: @fusionView.getElement(), visible: true)

        @subscriptions = new CompositeDisposable

        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:build': => @build()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:run': => @run()
        @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:package': => @package()
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

        Fusion.menu.saveAllOnBuild.checked = atom.config.get('fusion.saveAllOnBuild')
        atom.menu.update()

    deactivate: ->
        @modalPanel.destroy()
        @subscriptions.dispose()
        @fusionView.destroy()

    serialize: ->
        fusionViewState: @fusionView.serialize()

    # TODO add a way to further specify what a file needs to contain for a build system to handle it.
    build: ->
        if currentBuild?
            atom.notifications.addWarning('Build already in progress', {detail: 'Abort the previous build to continue'})
            return

        editor = atom.workspace.getActiveTextEditor()
        file = editor.getTitle()
        fileSplit = file.split('.')
        fileBaseName = fileSplit[0]
        fileType = fileSplit[fileSplit.length - 1];
        filePath = editor.getPath().split(file)[0]
        tmp = atom.project.getPaths()[0].split('/')
        projectName = tmp[tmp.length - 1]

        if atom.config.get('fusion.selectedBuildSystem') is 'Automatic' or atom.config.get('fusion.selectedBuildSystem') is null
            for i of buildSystems
                for j of buildSystems[i].extensions
                    if buildSystems[i].extensions[j].includes(fileType)
                        currentBuildSystem = buildSystems[i]

        atom.notifications.addInfo('Building...', {detail: 'using ' + currentBuildSystem.name + ' build system' + if atom.config.get('fusion.selectedBuildSystem') is 'Automatic' then ' (Auto)'})

        atom.commands.dispatch(atom.views.getView(atom.workspace), 'window:save-all') if atom.config.get('fusion.saveAllOnBuild') is true

        filledArgs = currentBuildSystem.commandSequence[0].arguments.slice(0)
        for i of filledArgs
            filledArgs[i] = filledArgs[i].replaceAll '{{file}}', file
            filledArgs[i] = filledArgs[i].replaceAll '{{file_base_name}}', fileBaseName
            filledArgs[i] = filledArgs[i].replaceAll '{{file_type}}', fileType
            filledArgs[i] = filledArgs[i].replaceAll '{{file_path}}', filePath
            filledArgs[i] = filledArgs[i].replaceAll '{{project_name}}', projectName

        Fusion.menu.cancel.enabled = true
        atom.menu.update()

        currentBuild = child_process.spawn currentBuildSystem.commandSequence[0].command, filledArgs, {cwd: filePath}
        currentBuild.on 'close', (code) ->
            Fusion.menu.cancel.enabled = false
            atom.menu.update()
            currentBuild = null
            atom.notifications.addSuccess('Build Finished', {detail: 'Finished with code ' + code})
        currentBuild.stdout.on 'data', (buffer) ->
            # TODO display build log
            console.log(buffer.toString())
        currentBuild.stderr.on 'data', (buffer) ->
            console.log(buffer.toString())
            atom.notifications.addError('Build Result', {detail: buffer})

    run: ->
        if currentBuild?
            atom.notifications.addWarning('Build already in progress', {detail: 'Abort the previous build to continue'})
            return

        editor = atom.workspace.getActiveTextEditor()
        file = editor.getTitle()
        fileSplit = file.split('.')
        fileBaseName = fileSplit[0]
        fileType = fileSplit[fileSplit.length - 1];
        filePath = editor.getPath().split(file)[0]
        tmp = atom.project.getPaths()[0].split('/')
        projectName = tmp[tmp.length - 1]

        if atom.config.get('fusion.selectedBuildSystem') is 'Automatic'
            for i of buildSystems
                for j of buildSystems[i].extensions
                    if buildSystems[i].extensions[j].includes(fileType)
                        currentBuildSystem = buildSystems[i]

        if currentBuildSystem.variants and currentBuildSystem.variants.run?
            atom.notifications.addInfo('Running...', {detail: 'using ' + currentBuildSystem.name + ' build system' + if atom.config.get('fusion.selectedBuildSystem') is 'Automatic' then ' (Auto)'})

            filledArgs = currentBuildSystem.variants.run.commandSequence[0].arguments.slice(0)
            for i of filledArgs
                filledArgs[i] = filledArgs[i].replaceAll '{{file}}', file
                filledArgs[i] = filledArgs[i].replaceAll '{{file_base_name}}', fileBaseName
                filledArgs[i] = filledArgs[i].replaceAll '{{file_type}}', fileType
                filledArgs[i] = filledArgs[i].replaceAll '{{file_path}}', filePath
                filledArgs[i] = filledArgs[i].replaceAll '{{project_name}}', projectName

            Fusion.menu.cancel.enabled = true
            atom.menu.update()

            currentBuild = child_process.spawn currentBuildSystem.variants.run.commandSequence[0].command, filledArgs, {cwd: filePath}
            currentBuild.on 'close', (code) ->
                Fusion.menu.cancel.enabled = false
                atom.menu.update()
                currentBuild = null
                atom.notifications.addSuccess('Run Finished', {detail: 'Finished with code ' + code})
            currentBuild.stdout.on 'data', (buffer) ->
                # TODO display run log
                console.log(buffer.toString())
            currentBuild.stderr.on 'data', (buffer) ->
                console.log(buffer.toString())
                atom.notifications.addError('Run Result', {detail: buffer})

    package: ->
        if currentBuild?
            atom.notifications.addWarning('Build already in progress', {detail: 'Abort the previous build to continue'})
            return

        editor = atom.workspace.getActiveTextEditor()
        file = editor.getTitle()
        fileSplit = file.split('.')
        fileBaseName = fileSplit[0]
        fileType = fileSplit[fileSplit.length - 1];
        filePath = editor.getPath().split(file)[0]
        tmp = atom.project.getPaths()[0].split('/')
        projectName = tmp[tmp.length - 1]

        if atom.config.get('fusion.selectedBuildSystem') is 'Automatic'
            for i of buildSystems
                for j of buildSystems[i].extensions
                    if buildSystems[i].extensions[j].includes(fileType)
                        currentBuildSystem = buildSystems[i]

        if currentBuildSystem.variants and currentBuildSystem.variants.package?
            atom.notifications.addInfo('Packaging...', {detail: 'using ' + currentBuildSystem.name + ' build system' + if atom.config.get('fusion.selectedBuildSystem') is 'Automatic' then ' (Auto)'})

            filledArgs = currentBuildSystem.variants.package.commandSequence[0].arguments.slice(0)
            for i of filledArgs
                filledArgs[i] = filledArgs[i].replaceAll '{{file}}', file
                filledArgs[i] = filledArgs[i].replaceAll '{{file_base_name}}', fileBaseName
                filledArgs[i] = filledArgs[i].replaceAll '{{file_type}}', fileType
                filledArgs[i] = filledArgs[i].replaceAll '{{file_path}}', filePath
                filledArgs[i] = filledArgs[i].replaceAll '{{project_name}}', projectName

            Fusion.menu.cancel.enabled = true
            atom.menu.update()

            currentBuild = child_process.spawn currentBuildSystem.variants.package.commandSequence[0].command, filledArgs, {cwd: filePath}
            currentBuild.on 'close', (code) ->
                Fusion.menu.cancel.enabled = false
                atom.menu.update()
                currentBuild = null
                atom.notifications.addSuccess('Packaging Finished', {detail: 'Finished with code ' + code})
            currentBuild.stdout.on 'data', (buffer) ->
                # TODO display package log
                console.log(buffer.toString())
            currentBuild.stderr.on 'data', (buffer) ->
                console.log(buffer.toString())
                atom.notifications.addError('Packaging Result', {detail: buffer})

    switchBuildSystemAuto: ->
        atom.config.set('fusion.selectedBuildSystem', 'Automatic')
        atom.notifications.addInfo('Switching build system', {detail: 'Switched to Auto'})
        Fusion.menu.build.enabled = true
        Fusion.menu.run.enabled = true
        Fusion.menu.package.enabled = true
        Fusion.menu.otherVariants.enabled = true
        Fusion.menu.otherVariants.submenu = []
        atom.menu.update()

    newBuildSystem: ->
        atom.notifications.addInfo('New Build System', {detail: 'this doesn\' work yet'})

    chooseBuildSystem: ->
        atom.notifications.addInfo('Choose Build System', {detail: 'this doesn\' work yet'})
        this.updateListOfBuildSystems()

    cancelBuild: ->
        if currentBuild
            currentBuild.kill()
            Fusion.menu.cancel.enabled = false
            atom.menu.update()
            atom.notifications.addInfo('Build Cancelled')

    showBuildResults: ->
        atom.notifications.addInfo('Showing build results', {detail: 'this doesn\' work yet'})

    showNextBuildResult: ->
        atom.notifications.addInfo('Showing next build result', {detail: 'this doesn\' work yet'})

    showPreviousBuildResult: ->
        atom.notifications.addInfo('Showing previous build result', {detail: 'this doesn\' work yet'})

    saveAllOnBuild: ->
        atom.config.set('fusion.saveAllOnBuild', !atom.config.get('fusion.saveAllOnBuild'))
        Fusion.menu.saveAllOnBuild.checked = atom.config.get('fusion.saveAllOnBuild')
        atom.menu.update()

    getFusionMenu: ->
        for i of atom.menu.template
            if atom.menu.template[i].label is "Packages"
                for j of atom.menu.template[i].submenu
                    if atom.menu.template[i].submenu[j].label is "Fusion"
                        Fusion.menu.parent = atom.menu.template[i].submenu[j]
                        Fusion.menu.buildSystems = atom.menu.template[i].submenu[j].submenu[0]
                        Fusion.menu.build = atom.menu.template[i].submenu[j].submenu[1]
                        Fusion.menu.run = atom.menu.template[i].submenu[j].submenu[2]
                        Fusion.menu.package = atom.menu.template[i].submenu[j].submenu[3]
                        Fusion.menu.otherVariants = atom.menu.template[i].submenu[j].submenu[4]
                        Fusion.menu.buildWith = atom.menu.template[i].submenu[j].submenu[5]
                        Fusion.menu.cancel = atom.menu.template[i].submenu[j].submenu[6]
                        Fusion.menu.buildResults = atom.menu.template[i].submenu[j].submenu[7]
                        Fusion.menu.saveAllOnBuild = atom.menu.template[i].submenu[j].submenu[8]

    getInstalledBuildSystems: ->
        defaultBuildSystems = []
        defaultBuildSystemsPath = atom.packages.resolvePackagePath('Fusion') + '/lib/build-systems/'
        defaultBuildSystemsNames = FS.readdirSync(defaultBuildSystemsPath)
        for i of defaultBuildSystemsNames
            defaultBuildSystems.push CSON.parse FS.readFileSync(defaultBuildSystemsPath + defaultBuildSystemsNames[i]).toString()

        installedBuildSystems = []
        installedPackages = atom.packages.getLoadedPackages()
        installedBuildSystemsPaths = []
        for i of installedPackages
            if installedPackages[i].name.startsWith 'fusion-build-'
                console.log 'Adding' + installedPackages[i].name + ' to active build systems'
                installedBuildSystemsPaths.push installedPackages[i].path
        for i of installedBuildSystemsPaths
            console.log i + ":" + installedBuildSystemsPaths[i]
            installedBuildSystems.push CSON.parse FS.readFileSync(installedBuildSystemsPaths[i] + '/lib/fusion-build.cson').toString()

        allBuildSystems = defaultBuildSystems.concat(installedBuildSystems)
        # TODO sort allBuildSystems alphabetically
        console.log allBuildSystems

        return allBuildSystems

    updateListOfBuildSystems: ->
        buildSystems = this.getInstalledBuildSystems()

        for i of buildSystems
            switchBuildSystemFuncs[buildSystems[i].name] = ((bs) ->
                return (->
                    currentBuildSystem = bs
                    atom.config.set('fusion.selectedBuildSystem', bs.name)
                    atom.notifications.addInfo('Switching build system', {detail: 'Switched to ' + bs.name})
                    Fusion.menu.build.enabled = if bs.commandSequence? then true else false
                    Fusion.menu.run.enabled = if bs.variants? and bs.variants.run? then true else false
                    Fusion.menu.package.enabled = if bs.variants? and bs.variants.package? then true else false
                    Fusion.menu.otherVariants.submenu = []
                    if bs.variants? and bs.variants.other? and bs.variants.other.length > 0
                        Fusion.menu.otherVariants.enabled = true
                        for i of bs.variants.other
                            # TODO add command to be able to run other build variants
                            Fusion.menu.otherVariants.submenu.push {label: bs.variants.other[i].name, command: ''}
                    else
                        Fusion.menu.otherVariants.enabled = false
                    atom.menu.update()
                )
            )(buildSystems[i])
            @subscriptions.add atom.commands.add 'atom-workspace', 'fusion:switch-build-system-' + buildSystems[i].name, switchBuildSystemFuncs[buildSystems[i].name]

            Fusion.menu.buildSystems.submenu.splice(Fusion.menu.buildSystems.submenu.length - 2, 0, {type: 'radio', label: buildSystems[i].name, command: 'fusion:switch-build-system-' + buildSystems[i].name, checked: (if atom.config.get('fusion.selectedBuildSystem') is buildSystems[i].name then true else false)})
        atom.menu.update()

String.prototype.replaceAll = (find, replace) ->
  return this.replace(new RegExp(find, 'g'), replace)
