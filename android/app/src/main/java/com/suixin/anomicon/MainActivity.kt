package com.suixin.anomicon

import android.app.Application
import android.os.Bundle
import androidx.activity.SystemBarStyle
import android.graphics.Color
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.suixin.anomicon.core.data.*
import dagger.hilt.android.AndroidEntryPoint
import dagger.hilt.android.HiltAndroidApp
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import android.content.Context
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltAndroidApp
class AnomiconApplication : Application()

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    private val model: ShellViewModel by viewModels()
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            ArchiveApp(model) { dark ->
                val style = if (dark) SystemBarStyle.dark(Color.TRANSPARENT)
                    else SystemBarStyle.light(Color.TRANSPARENT, Color.BLACK)
                enableEdgeToEdge(statusBarStyle = style, navigationBarStyle = style)
            }
        }
    }
}

internal enum class Tab(val title: String) { Explore("探索"), Catalog("图鉴"), Foundation("基金会"), Stories("故事"), Terminal("终端") }
internal enum class Detail(val title: String) { Web("原版网页"), Scene("三维档案馆"), Settings("设置"), About("关于格异录"), License("内容来源与许可"), Feedback("RAISA 终端运维工单") }

internal data class DetailRoute(
    val page: Detail,
    val item: String = "",
    val source: String = "",
    val title: String = "",
    val url: String = "",
    val renderMode: String = "",
    val revealed: Boolean = false,
    val key: String = java.util.UUID.randomUUID().toString(),
) : java.io.Serializable

internal sealed interface Bootstrap {
    data object Loading : Bootstrap
    data class Ready(val settings: AppSettings) : Bootstrap
    data class Error(val message: String) : Bootstrap
}

@HiltViewModel
internal class ShellViewModel @Inject constructor(@ApplicationContext context: Context, private val saved: SavedStateHandle) : ViewModel() {
    val data = NativeData.open(context)
    private val migration = MutableStateFlow<Bootstrap>(Bootstrap.Loading)
    val bootstrap = migration.asStateFlow()
    val tab = saved.getStateFlow("tab", Tab.Explore)
    val routes = saved.getStateFlow("detailRoutes", arrayListOf<DetailRoute>())
    fun push(route: DetailRoute) { saved["detailRoutes"] = ArrayList(routes.value + route) }
    fun open(page: Detail) = push(DetailRoute(page))
    fun openEntry(slug: String) = push(DetailRoute(Detail.Web, item = slug))
    fun back() { saved["detailRoutes"] = ArrayList(routes.value.dropLast(1)) }
    init { migrate() }
    fun migrate() {
        migration.value = Bootstrap.Loading
        viewModelScope.launch {
            try {
                data.migrateIfNeeded()
                data.settings.collect { migration.value = Bootstrap.Ready(it) }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Exception) {
                migration.value = Bootstrap.Error(failure.localizedMessage ?: "请重试")
            }
        }
    }
    fun select(value: Tab) { saved["tab"] = value; saved["detailRoutes"] = arrayListOf<DetailRoute>() }
    fun theme(value: ThemeMode) { viewModelScope.launch { data.setThemeMode(value) } }
    fun material(value: Boolean) { viewModelScope.launch { data.setImmersiveMaterial(value) } }
    fun haptics(value: Boolean) { viewModelScope.launch { data.setHaptics(value) } }
}
