"""Generate the native app target. SwiftPM manages its library dependencies."""
from pathlib import Path
import hashlib
import plistlib
root = Path(__file__).resolve().parent.parent
def ident(text): return hashlib.sha256(text.encode()).hexdigest()[:24].upper()
objects = []
update_key = (root / "Assets/UpdatePublicKey.txt").read_text().strip()
version = (root / "VERSION").read_text().strip()
info = {"SUFeedURL": "https://redditarun.github.io/palm/appcast.xml", "SUPublicEDKey": update_key,
        "SUEnableAutomaticChecks": False, "SUAutomaticallyUpdate": False, "SUVerifyUpdateBeforeExtraction": True}
(root / "Assets/PalmInfo.plist").write_bytes(plistlib.dumps(info))
def obj(key, body):
    objects.append(f'{ident(key)} = {{ {body} }};')
    return ident(key)
refs, builds = [], []
for source in sorted((root / 'Sources/Palm').glob('*.swift')):
    ref = obj(source.name, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "Sources/Palm/{source.name}"; sourceTree = "<group>";')
    refs.append(ref)
    builds.append(obj('build'+source.name, f'isa = PBXBuildFile; fileRef = {ref};'))
iconref = obj('icon', 'isa = PBXFileReference; lastKnownFileType = image.icns; path = Assets/Palm.icns; sourceTree = "<group>";')
iconbuild = obj('iconbuild', f'isa = PBXBuildFile; fileRef = {iconref};')
refs.append(iconref)
product = obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = Palm.app; sourceTree = BUILT_PRODUCTS_DIR;')
group = obj('group', f'isa = PBXGroup; children = ({",".join(refs+[product])}); sourceTree = "<group>";')
package = obj('package', 'isa = XCLocalSwiftPackageReference; relativePath = .;')
symbols_package = obj('symbols-package', 'isa = XCLocalSwiftPackageReference; relativePath = Vendor/CodeEditSymbols;')
symbols_dependency = obj('symbols-dependency', f'isa = XCSwiftPackageProductDependency; package = {symbols_package}; productName = CodeEditSymbols;')
symbols_link = obj('symbols-link', f'isa = PBXBuildFile; productRef = {symbols_dependency};')
dependency = obj('dependency', f'isa = XCSwiftPackageProductDependency; package = {package}; productName = PalmKit;')
link = obj('link', f'isa = PBXBuildFile; productRef = {dependency};')
sparkle_package = obj('sparkle-package', 'isa = XCRemoteSwiftPackageReference; repositoryURL = "https://github.com/sparkle-project/Sparkle.git"; requirement = { kind = exactVersion; version = 2.9.6; };')
sparkle_dependency = obj('sparkle-dependency', f'isa = XCSwiftPackageProductDependency; package = {sparkle_package}; productName = Sparkle;')
sparkle_link = obj('sparkle-link', f'isa = PBXBuildFile; productRef = {sparkle_dependency};')
frameworks = obj('frameworks' , f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ({link},{symbols_link},{sparkle_link}); runOnlyForDeploymentPostprocessing = 0;')
phase = obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)}); runOnlyForDeploymentPostprocessing = 0;')
resources = obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({iconbuild}); runOnlyForDeploymentPostprocessing = 0;')
configs = []
for kind in ['Debug', 'Release']:
    configs.append(obj(kind, f'''isa = XCBuildConfiguration; name = {kind}; buildSettings = {{
      PRODUCT_NAME = Palm; PRODUCT_BUNDLE_IDENTIFIER = app.plam.learning; MACOSX_DEPLOYMENT_TARGET = 15.0;
      ARCHS = arm64; ONLY_ACTIVE_ARCH = YES; ALWAYS_SEARCH_USER_PATHS = NO; SDKROOT = macosx; SWIFT_VERSION = 5.0; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_FILE = Assets/PalmInfo.plist;
      INFOPLIST_KEY_CFBundleDisplayName = Palm; INFOPLIST_KEY_CFBundleIconFile = Palm; INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.education";
      INFOPLIST_KEY_NSHighResolutionCapable = YES; CODE_SIGN_IDENTITY = "-"; CODE_SIGN_STYLE = Manual;
      ENABLE_APP_SANDBOX = NO; CURRENT_PROJECT_VERSION = "{version}"; MARKETING_VERSION = "{version}";
      INFOPLIST_KEY_NSMicrophoneUsageDescription = "Dictate answers and tutor messages. Speech recognition runs locally on your Mac.";
      SWIFT_ACTIVE_COMPILATION_CONDITIONS = "{'DEBUG' if kind == 'Debug' else ''}";
      SWIFT_OPTIMIZATION_LEVEL = "{'-Onone' if kind == 'Debug' else '-O'}";
      LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks";
    }};'''))
configlist = obj('configlist', f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;')
target = obj('target', f'isa = PBXNativeTarget; name = Palm; productName = Palm; productType = "com.apple.product-type.application"; productReference = {product}; buildConfigurationList = {configlist}; buildPhases = ({phase},{frameworks},{resources}); buildRules = (); dependencies = (); packageProductDependencies = ({dependency},{symbols_dependency},{sparkle_dependency});')
project = obj('project', f'isa = PBXProject; buildConfigurationList = {configlist}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en, Base); mainGroup = {group}; productRefGroup = {group}; projectDirPath = ""; projectRoot = ""; targets = ({target}); packageReferences = ({package},{symbols_package},{sparkle_package}); attributes = {{ LastUpgradeCheck = 2600; }};')
dest = root/'Palm.xcodeproj'; dest.mkdir(exist_ok=True)
(dest/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+ '\n'.join(objects) + f'\n}}; rootObject = {project}; }}\n')
scheme_dir = dest / 'xcshareddata/xcschemes'; scheme_dir.mkdir(parents=True, exist_ok=True)
(scheme_dir/'PalmMac.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Palm.app" BlueprintName="Palm" ReferencedContainer="container:Palm.xcodeproj"/>
    </BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Palm.app" BlueprintName="Palm" ReferencedContainer="container:Palm.xcodeproj"/></BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
