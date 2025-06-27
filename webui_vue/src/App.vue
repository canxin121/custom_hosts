<script setup lang="ts">
import { ref, onMounted, reactive } from 'vue'
import { exec, spawn, toast } from 'kernelsu'
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

const { Title, Text, Paragraph } = Typography
const { TextArea } = Input

// 模块配置
const MODULE_CONFIG = {
  MODULE_PATH: '/data/adb/modules/custom_hosts',
  CUSTOM_HOSTS_FILE: 'custom_hosts.txt',
  TARGET_HOSTS_FILE: 'system/etc/hosts',
  UPDATE_SCRIPT: 'update_hosts.sh',
  TEMP_DIR: '/data/local/tmp',
}

// 响应式状态
const state = reactive({
  moduleStatus: 'checking',
  hostsContent: '',
  logMessages: [] as Array<{
    time: string
    message: string
    type: 'info' | 'success' | 'error' | 'warning'
  }>,
  loading: false,
  currentHosts: '',
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
    toast(`✅ ${message}`)
  } else if (type === 'error') {
    toast(`❌ ${message}`)
  }
}

// 检查模块状态
const checkModuleStatus = async () => {
  try {
    addLog('检查模块状态...')
    const result = await exec(`ls -la ${getModulePath()}/`)

    if (result.errno === 0) {
      state.moduleStatus = 'active'
      addLog('模块已安装并运行正常', 'success')
    } else {
      state.moduleStatus = 'inactive'
      addLog('模块未找到或未正常运行', 'error')
    }
  } catch (error) {
    state.moduleStatus = 'error'
    addLog(`检查模块状态失败: ${error}`, 'error')
  }
}

// 加载并查看hosts配置
const loadAndViewHosts = async () => {
  if (state.loading) return

  state.loading = true
  try {
    addLog('加载Hosts配置...')
    const result = await exec(`cat ${getModulePath(MODULE_CONFIG.CUSTOM_HOSTS_FILE)}`)

    if (result.errno === 0) {
      state.hostsContent = result.stdout
      addLog('Hosts配置已加载', 'success')
    } else {
      addLog('加载Hosts配置失败，尝试加载系统默认hosts', 'warning')
      // 如果自定义配置不存在，尝试加载系统hosts文件
      const systemResult = await exec(
        `cat ${getModulePath(MODULE_CONFIG.TARGET_HOSTS_FILE)} 2>/dev/null || cat /system/etc/hosts`,
      )
      if (systemResult.errno === 0) {
        state.hostsContent = systemResult.stdout
        addLog('已加载系统默认hosts文件', 'success')
      } else {
        addLog('无法加载任何hosts文件', 'error')
      }
    }

    // 同时获取当前生效的hosts文件用于预览
    addLog('获取当前生效的Hosts文件...')
    const currentResult = await exec(
      `cat ${getModulePath(MODULE_CONFIG.TARGET_HOSTS_FILE)} 2>/dev/null || cat /system/etc/hosts`,
    )
    if (currentResult.errno === 0) {
      state.currentHosts = currentResult.stdout
      addLog('已获取当前生效的Hosts文件', 'success')
    }
  } catch (error) {
    addLog(`加载配置异常: ${error}`, 'error')
  } finally {
    state.loading = false
  }
}

// 保存并更新hosts配置
const saveAndUpdateHosts = async () => {
  if (state.loading) return
  if (!state.hostsContent.trim()) {
    message.warning('配置内容不能为空')
    return
  }

  state.loading = true
  try {
    addLog('保存Hosts配置...')
    const tempFile = `${MODULE_CONFIG.TEMP_DIR}/custom_hosts_temp.txt`
    const escapedContent = state.hostsContent.replace(/'/g, "'\\''")

    // 先保存配置文件
    const saveResult = await exec(
      `echo '${escapedContent}' > ${tempFile} && mv ${tempFile} ${getModulePath(MODULE_CONFIG.CUSTOM_HOSTS_FILE)}`,
    )

    if (saveResult.errno === 0) {
      addLog('Hosts配置已保存', 'success')

      // 然后更新系统hosts文件
      addLog('更新系统Hosts文件...')
      const updateResult = await exec(`sh ${getModulePath(MODULE_CONFIG.UPDATE_SCRIPT)}`)

      if (updateResult.errno === 0) {
        addLog('Hosts文件更新完成，重启后生效', 'success')
      } else {
        addLog('更新Hosts文件失败，但配置已保存', 'warning')
      }
    } else {
      addLog('保存配置失败', 'error')
    }
  } catch (error) {
    addLog(`操作异常: ${error}`, 'error')
  } finally {
    state.loading = false
  }
}

// 组件挂载时初始化
onMounted(async () => {
  addLog('Custom Hosts WebUI 已加载', 'success')
  await checkModuleStatus()
  if (state.moduleStatus === 'active') {
    await loadAndViewHosts()
  }
})
</script>

<template>
  <div style="padding: 24px; min-height: 100vh; background-color: #f5f5f5">
    <!-- 标题区域 -->
    <div style="text-align: center; margin-bottom: 32px">
      <Title :level="1">🌐 Custom Hosts</Title>
      <Text type="secondary">KernelSU 自定义 Hosts 管理器</Text>
    </div>

    <Row :gutter="[16, 16]">
      <!-- 左侧主要操作区域 -->
      <Col :xs="24" :lg="16">
        <!-- 模块状态 -->
        <Card title="📊 模块状态" style="margin-bottom: 16px">
          <Space>
            <Tag v-if="state.moduleStatus === 'active'" color="success">✅ 模块运行正常</Tag>
            <Tag v-else-if="state.moduleStatus === 'inactive'" color="error">❌ 模块未运行</Tag>
            <Tag v-else-if="state.moduleStatus === 'error'" color="error">❌ 模块错误</Tag>
            <Tag v-else color="processing">🔄 检查中...</Tag>

            <Button @click="checkModuleStatus" :loading="state.loading"> 刷新状态 </Button>
          </Space>
        </Card>

        <!-- Hosts编辑器 -->
        <Card title="✏️ Hosts 配置管理">

          <Alert
            message="配置说明"
            description="在下面的文本框中编辑您的自定义 hosts 条目。格式：IP地址 域名"
            type="info"
            show-icon
            style="margin-bottom: 16px"
          />

          <TextArea
            v-model:value="state.hostsContent"
            :rows="12"
            placeholder="# 添加您的自定义 hosts 条目
# 格式示例：
# 127.0.0.1       example.com
# 192.168.1.100   local.server
# 0.0.0.0         ads.example.com"
            style="font-family: 'Courier New', monospace"
          />

            <div style="margin-top: 16px; display: flex; justify-content: flex-end;">
            <Space wrap>
              <Button @click="loadAndViewHosts" :loading="state.loading"> 📂 加载配置 </Button>
              <Button type="primary" @click="saveAndUpdateHosts" :loading="state.loading">
              🚀 保存并应用
              </Button>
            </Space>
            </div>
        </Card>
      </Col>

      <!-- 右侧日志区域 -->
      <Col :xs="24" :lg="8">
        <!-- 当前Hosts预览 -->
        <Card v-if="state.currentHosts" title="📄 当前 Hosts 内容" style="margin-bottom: 16px">
          <TextArea
            :value="state.currentHosts"
            :rows="8"
            readonly
            style="font-family: 'Courier New', monospace; font-size: 12px"
          />
        </Card>

        <!-- 操作日志 -->
        <Card title="📝 操作日志">
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
                  style="font-size: 12px; font-family: 'Courier New', monospace"
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
          <div style="font-size: 24px">⚡</div>
        </template>
      </Spin>
    </div>
  </div>
</template>

<style scoped>
/* 移除多余的CSS，使用Ant Design Vue的样式 */
</style>
