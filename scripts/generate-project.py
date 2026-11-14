#!/usr/bin/env python3
"""Dependency-free deterministic Xcode project generator. XcodeGen is optional."""
import hashlib, json, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
objects = {}
def ident(key): return hashlib.sha256(key.encode()).hexdigest()[:24].upper()
def add(key, **values):
    i = ident(key); objects[i] = values; return i
def configs(name, base):
    refs = []
    for mode in ['Debug', 'Release']:
        settings = dict(base)
        if mode == 'Debug': settings.update(SWIFT_OPTIMIZATION_LEVEL='-Onone', DEBUG_INFORMATION_FORMAT='dwarf', ENABLE_TESTABILITY='YES', SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) DEBUG ' + base.get('SWIFT_ACTIVE_COMPILATION_CONDITIONS', ''))
        else: settings.update(SWIFT_OPTIMIZATION_LEVEL='-O', DEBUG_INFORMATION_FORMAT='dwarf-with-dsym')
        refs.append(add(name+mode, isa='XCBuildConfiguration', name=mode, buildSettings=settings))
    return add(name+'configlist', isa='XCConfigurationList', buildConfigurations=refs, defaultConfigurationIsVisible='0', defaultConfigurationName='Release')
file_refs = {}
for folder in ['MyFinance', 'MyFinanceTests', 'MyFinanceWidgets']:
    for path in sorted((root / folder).rglob('*')):
        if not path.is_file(): continue
        rel = str(path.relative_to(root))
        if path.suffix not in ['.swift', '.plist', '.xcprivacy']: continue
        file_refs[rel] = add('file:'+rel, isa='PBXFileReference', path=rel, sourceTree='SOURCE_ROOT', lastKnownFileType={'.swift':'sourcecode.swift','.plist':'text.plist.xml','.xcprivacy':'text.xml'}[path.suffix])
for path in sorted((root / 'MyFinance').rglob('*.xcassets')):
    rel = str(path.relative_to(root))
    file_refs[rel] = add('file:'+rel, isa='PBXFileReference', path=rel, sourceTree='SOURCE_ROOT', lastKnownFileType='folder.assetcatalog')
product_refs = {}
for name, ext in [('MyFinance','app'),('MyFinanceTests','xctest'),('MyFinanceCoreTests','xctest'),('MyFinanceWidgets','appex')]:
    product_refs[name] = add('product:'+name, isa='PBXFileReference', explicitFileType={'app':'wrapper.application','xctest':'wrapper.cfbundle','appex':'wrapper.app-extension'}[ext], includeInIndex='0', path=name+'.'+ext, sourceTree='BUILT_PRODUCTS_DIR')
products = add('products',isa='PBXGroup',children=list(product_refs.values()),name='Products',sourceTree='<group>')
main_group = add('mainGroup',isa='PBXGroup',children=list(file_refs.values())+[products],sourceTree='<group>')
base = dict(SWIFT_VERSION='5.0', IPHONEOS_DEPLOYMENT_TARGET='17.0', SDKROOT='iphoneos', TARGETED_DEVICE_FAMILY='1', CODE_SIGN_STYLE='Automatic', PRODUCT_NAME='$(TARGET_NAME)', CLANG_ENABLE_MODULES='YES', ENABLE_USER_SCRIPT_SANDBOXING='YES', SWIFT_EMIT_LOC_STRINGS='YES')
target_ids = []
for name in product_refs:
    is_test = name.endswith('Tests'); widget = name.endswith('Widgets')
    if name == 'MyFinance': paths = [p for p in file_refs if p.startswith('MyFinance/')]
    elif name == 'MyFinanceCoreTests': paths = [p for p in file_refs if p.startswith('MyFinanceTests/Core/') or p.startswith('MyFinance/Core/Finance/')]
    elif name == 'MyFinanceTests': paths = [p for p in file_refs if p.startswith('MyFinanceTests/iOS/')]
    else: paths = [p for p in file_refs if p.startswith('MyFinanceWidgets/')]
    sources=[]; resources=[]
    for p in paths:
        if p.endswith('.plist'): continue
        build = add('build:'+name+':'+p, isa='PBXBuildFile', fileRef=file_refs[p])
        (sources if p.endswith('.swift') else resources).append(build)
    phases=[add('sources:'+name,isa='PBXSourcesBuildPhase',buildActionMask='2147483647',files=sources,runOnlyForDeploymentPostprocessing='0'), add('frameworks:'+name,isa='PBXFrameworksBuildPhase',buildActionMask='2147483647',files=[],runOnlyForDeploymentPostprocessing='0'),add('resources:'+name,isa='PBXResourcesBuildPhase',buildActionMask='2147483647',files=resources,runOnlyForDeploymentPostprocessing='0')]
    settings=dict(base,PRODUCT_BUNDLE_IDENTIFIER='com.example.'+name,LD_RUNPATH_SEARCH_PATHS=['$(inherited)','@executable_path/Frameworks'],CURRENT_PROJECT_VERSION='2',MARKETING_VERSION='1.1')
    deps=[]
    if is_test:
        settings['GENERATE_INFOPLIST_FILE']='YES'
        if name=='MyFinanceCoreTests': settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='CORE_INTEGRATED_TESTS'
        else:
            settings.update(TEST_HOST='$(BUILT_PRODUCTS_DIR)/MyFinance.app/MyFinance',BUNDLE_LOADER='$(TEST_HOST)')
            proxy=add('proxy:'+name,isa='PBXContainerItemProxy',containerPortal=ident('project'),proxyType='1',remoteGlobalIDString=ident('target:MyFinance'),remoteInfo='MyFinance')
            deps=[add('dependency:'+name,isa='PBXTargetDependency',target=ident('target:MyFinance'),targetProxy=proxy)]
    else:
        settings['INFOPLIST_FILE']='MyFinanceWidgets/Info.plist' if widget else 'MyFinance/Resources/Info.plist'
        settings['GENERATE_INFOPLIST_FILE']='NO'
    if name == 'MyFinance': settings['ASSETCATALOG_COMPILER_APPICON_NAME']='AppIcon'
    if widget: settings.update(SKIP_INSTALL='YES',APPLICATION_EXTENSION_API_ONLY='YES')
    target_ids.append(add('target:'+name,isa='PBXNativeTarget',buildConfigurationList=configs(name,settings),buildPhases=phases,buildRules=[],dependencies=deps,name=name,productName=name,productReference=product_refs[name],productType='com.apple.product-type.bundle.unit-test' if is_test else 'com.apple.product-type.app-extension' if widget else 'com.apple.product-type.application'))
project_id=add('project',isa='PBXProject',attributes={'LastUpgradeCheck':'1600','BuildIndependentTargetsInParallel':'YES'},buildConfigurationList=configs('project',dict(CLANG_ENABLE_OBJC_ARC='YES',CLANG_WARN_DOCUMENTATION_COMMENTS='YES')),compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings='0',knownRegions=['en','Base'],mainGroup=main_group,productRefGroup=products,projectDirPath='',projectRoot='',targets=target_ids)
def serialize(v, level=0):
    if isinstance(v,dict): return '{\n'+''.join('\t'*(level+1)+json.dumps(k)+' = '+serialize(val,level+1)+';\n' for k,val in v.items())+'\t'*level+'}'
    if isinstance(v,list): return '('+', '.join(serialize(x,level+1) for x in v)+')'
    return json.dumps(str(v))
project=root/'MyFinance.xcodeproj'; project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n'+serialize(dict(archiveVersion='1',classes={},objectVersion='56',objects=objects,rootObject=project_id))+'\n')
schemes=project/'xcshareddata/xcschemes'; schemes.mkdir(parents=True,exist_ok=True)
def ref(name): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident("target:"+name)}" BuildableName="{name}.{ "app" if name == "MyFinance" else "xctest" if name.endswith("Tests") else "appex"}" BlueprintName="{name}" ReferencedContainer="container:MyFinance.xcodeproj"/>'
(schemes/'MyFinance.xcscheme').write_text('<?xml version="1.0" encoding="UTF-8"?>\n<Scheme LastUpgradeVersion="1600" version="1.7"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">'+ref('MyFinance')+'</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables>'+''.join('<TestableReference skipped="NO">'+ref(n)+'</TestableReference>' for n in ['MyFinanceTests','MyFinanceCoreTests'])+'</Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">'+ref('MyFinance')+'</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">'+ref('MyFinance')+'</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>')
print(f'Generated {project.name}: {len(target_ids)} targets, {len(file_refs)} source/configuration references')
