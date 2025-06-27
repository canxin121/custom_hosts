import 'ant-design-vue/dist/reset.css';
import Antd from 'ant-design-vue';
import App from './App.vue'
import { createApp } from 'vue';
import { createPinia } from 'pinia';

const app = createApp(App)

app.use(createPinia())
app.use(Antd)

app.mount('#app')
