<script setup lang="ts">
import { onMounted, reactive } from 'vue'
import { exec, toast } from 'kernelsu'
import {
  Card,
  Button,
  Input,
  Row,
  Col,
  Space,
  Typography,
  Tag,
  Alert,
  message,
  Spin,
} from 'ant-design-vue'
// 导入所需的图标
import { ReloadOutlined, InfoCircleOutlined } from '@ant-design/icons-vue'

const { Title, Text } = Typography
const { TextArea } = Input

// 模块配置
const MODULE_CONFIG = {
  MODULE_PATH: '/data/adb/modules/custom_hosts',
  TARGET_HOSTS_FILE: 'system/etc/hosts',
  SYSTEM_HOSTS_FILE: '/system/etc/hosts',
  TEMP_DIR: '/data/local/tmp',
}

// 响应式状态
const state = reactive({
  moduleStatus: 'checking' as 'checking' | 'active' | 'inactive' | 'reboot_required' | 'error', // Add new status
  hostsContent: '',
  logMessages: [] as Array<{
    time: string
    message: string
    type: 'info' | 'success' | 'error' | 'warning'
  }>,
  loading: false,
  systemHosts: '',
  showConfigInfo: false, // 添加新的状态属性控制配置说明显示
})

// 构建模块路径
const getModulePath = (subPath = '') => {
  return subPath ? `${MODULE_CONFIG.MODULE_PATH}/${subPath}` : MODULE_CONFIG.MODULE_PATH
}

// 日志记录
const addLog = (message: string, type: 'info' | 'success' | 'error' | 'warning' = 'info') => {
  const time = new Date().toLocaleTimeString()
  state.logMessages.push({ time, message, type })

  // 显示toast通知
  if (type === 'success') {
    toast(`${message}`)
  } else if (type === 'error') {
    toast(`${message}`)
  }
}

// 检查模块状态
const checkModuleStatus = async () => {
  try {
    addLog('检查模块状态...')
    state.moduleStatus = 'checking' // Set to checking while processing

    // 1. Check if module directory exists
    const moduleDirCheck = await exec(`ls -d ${getModulePath()}`)
    if (moduleDirCheck.errno !== 0) {
      state.moduleStatus = 'inactive'
      addLog('模块目录未找到', 'error')
      return // Module is not installed
    }

    // 2. Read module hosts file
    const moduleHostsPath = getModulePath(MODULE_CONFIG.TARGET_HOSTS_FILE)
    const moduleHostsResult = await exec(`cat ${moduleHostsPath}`)
    if (moduleHostsResult.errno !== 0) {
      // This might happen if the module is installed but the hosts file wasn't created correctly
      state.moduleStatus = 'error'
      addLog(`无法读取模块Hosts文件: ${moduleHostsPath}`, 'error')
      return
    }
    const moduleHostsContent = moduleHostsResult.stdout.trim()

    // 3. Read system hosts file
    const systemHostsPath = MODULE_CONFIG.SYSTEM_HOSTS_FILE
    const systemHostsResult = await exec(`cat ${systemHostsPath}`)
    if (systemHostsResult.errno !== 0) {
      state.moduleStatus = 'error'
      addLog(`无法读取系统Hosts文件: ${systemHostsPath}`, 'error')
      return
    }
    const systemHostsContent = systemHostsResult.stdout.trim()

    // 4. Compare content
    if (moduleHostsContent === systemHostsContent) {
      state.moduleStatus = 'active'
      addLog('模块Hosts配置与系统Hosts一致', 'success')
    } else {
      state.moduleStatus = 'reboot_required'
      addLog('模块Hosts配置与系统Hosts不一致，需要重启生效', 'warning')
    }
  } catch (error) {
    state.moduleStatus = 'error'
    addLog(`检查模块状态失败: ${error}`, 'error')
  }
}

// 加载模块hosts配置（用于编辑）
const loadModuleHosts = async () => {
  if (state.loading) return

  state.loading = true
  try {
    addLog('加载模块Hosts配置...')
    const result = await exec(`cat ${getModulePath(MODULE_CONFIG.TARGET_HOSTS_FILE)}`)

    if (result.errno === 0) {
      state.hostsContent = result.stdout
      addLog('模块Hosts配置已加载', 'success')
    } else {
      addLog('模块Hosts配置不存在，创建默认配置', 'warning')
      // 如果模块配置不存在，从系统hosts创建一个默认配置
      const systemResult = await exec(`cat ${MODULE_CONFIG.SYSTEM_HOSTS_FILE}`)
      if (systemResult.errno === 0) {
        state.hostsContent = `# Custom hosts file - managed by KernelSU Custom Hosts module
# Add your custom host entries below:
# Format: IP_ADDRESS    DOMAIN_NAME

# Your custom entries go here:


# ====================================================================
# Original system hosts content below:
# ====================================================================

${systemResult.stdout}`
        addLog('已基于系统hosts创建默认配置', 'success')
      } else {
        state.hostsContent = `# Custom hosts file - managed by KernelSU Custom Hosts module
# Add your custom host entries below:
# Format: IP_ADDRESS    DOMAIN_NAME

127.0.0.1       localhost
::1             localhost`
        addLog('已创建基础默认配置', 'success')
      }
    }
  } catch (error) {
    addLog(`加载配置异常: ${error}`, 'error')
  } finally {
    state.loading = false
  }
}

// 加载系统当前hosts（用于预览）
const loadSystemHosts = async () => {
  try {
    addLog('获取系统当前Hosts文件...')
    const result = await exec(`cat ${MODULE_CONFIG.SYSTEM_HOSTS_FILE}`)

    if (result.errno === 0) {
      state.systemHosts = result.stdout
      addLog('已获取系统当前Hosts文件', 'success')
    } else {
      addLog('无法读取系统Hosts文件', 'error')
    }
  } catch (error) {
    addLog(`读取系统Hosts异常: ${error}`, 'error')
  }
}

// 保存hosts配置
const saveHosts = async () => {
  if (state.loading) return
  if (!state.hostsContent.trim()) {
    message.warning('配置内容不能为空')
    return
  }

  state.loading = true
  try {
    addLog('保存Hosts配置...')

    // 确保目标目录存在
    await exec(`mkdir -p ${getModulePath('system/etc')}`)

    const tempFile = `${MODULE_CONFIG.TEMP_DIR}/hosts_temp.txt`
    const escapedContent = state.hostsContent.replace(/'/g, "'\\''")

    // 保存到模块的hosts文件
    const saveResult = await exec(
      `echo '${escapedContent}' > ${tempFile} && mv ${tempFile} ${getModulePath(MODULE_CONFIG.TARGET_HOSTS_FILE)}`,
    )

    if (saveResult.errno === 0) {
      addLog('Hosts配置已保存', 'success')

      // 尝试立即通过绑定挂载应用更改
      const moduleHosts = getModulePath(MODULE_CONFIG.TARGET_HOSTS_FILE)
      const systemHosts = MODULE_CONFIG.SYSTEM_HOSTS_FILE
      addLog('尝试立即应用（bind mount）...', 'info')

      // 先修正源文件权限与 SELinux 上下文，再尝试多种 mount 实现
      const mountCmd = `
chown 0:0 '${moduleHosts}' 2>/dev/null || true
chmod 0644 '${moduleHosts}' 2>/dev/null || true
chcon u:object_r:system_file:s0 '${moduleHosts}' 2>/dev/null || true
if mount | grep -q ' /system/etc/hosts '; then umount '/system/etc/hosts' 2>/dev/null || true; fi
mount -o bind '${moduleHosts}' '${systemHosts}' 2>/dev/null || toybox mount -o bind '${moduleHosts}' '${systemHosts}' 2>/dev/null || busybox mount -o bind '${moduleHosts}' '${systemHosts}'
`
      const m = await exec(mountCmd)
      if (m.errno === 0) {
        addLog('已通过绑定挂载立即应用', 'success')
      } else {
        addLog('无法立即应用，更改将在重启后生效', 'warning')
      }

      // 刷新系统hosts预览
      await loadSystemHosts()
      // 保存成功后刷新模块状态
      await checkModuleStatus()
    } else {
      addLog('保存配置失败', 'error')
    }
  } catch (error) {
    addLog(`操作异常: ${error}`, 'error')
  } finally {
    state.loading = false
  }
}

// 切换配置说明的显示状态
const toggleConfigInfo = () => {
  state.showConfigInfo = !state.showConfigInfo
}

// 组件挂载时初始化
onMounted(async () => {
  addLog('Custom Hosts WebUI 已加载', 'success')
  await checkModuleStatus()
  // 无论模块状态如何，都尝试加载配置和系统hosts
  await loadModuleHosts() // Unconditionally load module hosts
  await loadSystemHosts() // Unconditionally load system hosts
})
</script>

<template>
  <div style="padding: 24px; min-height: 100vh; background-color: #f5f5f5">
    <!-- 标题区域 -->
    <div style="text-align: center; margin-bottom: 32px">
      <Title :level="1">Custom Hosts</Title>
      <Text type="secondary">KernelSU 自定义 Hosts 管理器</Text>
    </div>

    <Row :gutter="[16, 16]">
      <!-- 左侧主要操作区域 -->
      <Col :xs="24" :lg="16">
        <!-- 模块状态 -->
        <Card title="模块状态" style="margin-bottom: 16px">
          <template #extra>
            <!-- 刷新状态图标按钮 -->
            <Button type="link" @click="checkModuleStatus" :loading="state.loading">
              <template #icon><ReloadOutlined /></template>
            </Button>
          </template>
          <div style="text-align: center">
            <Space :size="16">
              <Tag v-if="state.moduleStatus === 'active'" color="success">模块运行正常</Tag>
              <Tag v-else-if="state.moduleStatus === 'inactive'" color="error">模块已被删除</Tag>
              <Tag v-else-if="state.moduleStatus === 'error'" color="error">模块运行出错</Tag>
              <Tag v-else-if="state.moduleStatus === 'reboot_required'" color="warning"
                >需要重启生效</Tag
              >
              <Tag v-else color="processing">检查中...</Tag>
            </Space>
          </div>
        </Card>

        <!-- Hosts编辑器 -->
        <Card title="模块 Hosts内容">
          <!-- 在 Card 的 extra slot 添加按钮 -->
          <template #extra>
            <Space>
              <!-- 加载配置图标按钮 -->
              <Button type="link" @click.prevent="loadModuleHosts" :loading="state.loading">
                <template #icon><ReloadOutlined /></template>
              </Button>
              <!-- 显示说明图标按钮 -->
              <Button type="link" @click="toggleConfigInfo">
                <template #icon><InfoCircleOutlined /></template>
              </Button>
            </Space>
          </template>

          <!-- 根据 showConfigInfo 状态条件渲染 Alert -->
          <Alert
            v-if="state.showConfigInfo"
            message="配置说明"
            description="直接编辑模块的 hosts 文件内容。保存后需要重启设备才能生效。"
            type="info"
            show-icon
            style="margin-bottom: 16px"
          />

          <TextArea
            v-model:value="state.hostsContent"
            :rows="12"
            placeholder="# 模块 hosts 配置文件\n# 格式示例：\n# 127.0.0.1       example.com\n# 192.168.1.100   local.server\n# 0.0.0.0         ads.example.com"
            style="
              font-family:
                'SFMono-Regular', 'Consolas', 'Liberation Mono', 'Menlo', 'Monaco', monospace;
              font-size: 13px;
              line-height: 1.4;
              letter-spacing: 0;
            "
          />

          <div style="margin-top: 16px; display: flex; justify-content: flex-end">
            <Space wrap>
              <!-- 保存配置按钮不变 -->
              <Button type="primary" @click.prevent="saveHosts" :loading="state.loading">
                保存并应用配置
              </Button>
            </Space>
          </div>
        </Card>
      </Col>

      <!-- 右侧日志区域 -->
      <Col :xs="24" :lg="8">
        <!-- 系统Hosts预览 -->
        <Card title="系统 Hosts内容" style="margin-bottom: 16px">
          <template #extra>
            <!-- 刷新系统Hosts图标按钮 -->
            <Button size="small" type="link" @click="loadSystemHosts" :loading="state.loading">
              <template #icon><ReloadOutlined /></template>
            </Button>
          </template>
          <TextArea
            :value="state.systemHosts"
            :rows="8"
            readonly
            style="
              font-family:
                'SFMono-Regular', 'Consolas', 'Liberation Mono', 'Menlo', 'Monaco', monospace;
              font-size: 12px;
              line-height: 1.4;
              letter-spacing: 0;
            "
          />
        </Card>

        <!-- 操作日志 -->
        <Card title="操作日志">
          <div style="max-height: 300px; overflow-y: auto">
            <div
              v-for="(log, index) in state.logMessages"
              :key="index"
              style="
                margin-bottom: 8px;
                padding: 8px;
                background-color: #fafafa;
                border-radius: 4px;
              "
            >
              <div style="display: flex; justify-content: space-between; align-items: center">
                <Text
                  :type="
                    log.type === 'error'
                      ? 'danger'
                      : log.type === 'success'
                        ? 'success'
                        : log.type === 'warning'
                          ? 'warning'
                          : undefined
                  "
                  style="
                    font-size: 12px;
                    font-family:
                      'SFMono-Regular', 'Consolas', 'Liberation Mono', 'Menlo', 'Monaco', monospace;
                    line-height: 1.4;
                    letter-spacing: 0;
                  "
                >
                  {{ log.message }}
                </Text>
                <Text type="secondary" style="font-size: 10px">{{ log.time }}</Text>
              </div>
            </div>

            <div v-if="state.logMessages.length === 0" style="text-align: center; color: #999">
              暂无日志记录
            </div>
          </div>
        </Card>
      </Col>
    </Row>

    <!-- 全局加载遮罩 -->
    <div
      v-if="state.loading"
      style="
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: rgba(255, 255, 255, 0.8);
        z-index: 1000;
        display: flex;
        align-items: center;
        justify-content: center;
      "
    >
      <Spin size="large">
        <template #indicator>
          <div></div>
        </template>
      </Spin>
    </div>
  </div>
</template>

<style scoped>
/* 优化等宽字体显示 */
.ant-input {
  font-variant-ligatures: none; /* 禁用连字符，确保等宽字体正确显示 */
}

/* 自定义等宽字体类 */
.monospace-text {
  font-family:
    'SFMono-Regular', 'Consolas', 'Liberation Mono', 'Menlo', 'Monaco', 'Courier New', monospace;
  font-size: 13px;
  line-height: 1.4;
  letter-spacing: 0;
  font-weight: normal;
  font-variant-ligatures: none;
}

/* 小号等宽字体 */
.monospace-small {
  font-family:
    'SFMono-Regular', 'Consolas', 'Liberation Mono', 'Menlo', 'Monaco', 'Courier New', monospace;
  font-size: 12px;
  line-height: 1.4;
  letter-spacing: 0;
  font-weight: normal;
  font-variant-ligatures: none;
}
</style>
