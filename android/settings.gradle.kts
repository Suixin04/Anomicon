pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = "Anomicon"
include(":app", ":core:designsystem", ":core:data", ":core:network", ":feature:web", ":feature:archive3d")
include(":feature:discovery", ":feature:foundation", ":feature:stories", ":feature:terminal")
