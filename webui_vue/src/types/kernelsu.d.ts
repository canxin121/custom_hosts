// KernelSU 库的 TypeScript 类型声明

declare module 'kernelsu' {
  // 执行命令的选项
  interface ExecOptions {
    cwd?: string
    env?: Record<string, string>
  }

  // 执行结果
  interface ExecResult {
    errno: number
    stdout: string
    stderr: string
  }

  // Spawn 选项
  interface SpawnOptions {
    cwd?: string
    env?: Record<string, string>
  }

  // 可读流接口
  interface ReadableStream {
    on(event: 'data', callback: (data: string) => void): void
  }

  // 子进程接口
  interface ChildProcess {
    stdout: ReadableStream
    stderr: ReadableStream
    on(event: 'exit', callback: (code: number) => void): void
    on(event: 'error', callback: (error: Error) => void): void
  }

  // 导出的函数
  export function exec(command: string, options?: ExecOptions): Promise<ExecResult>
  export function spawn(command: string, args?: string[], options?: SpawnOptions): ChildProcess
  export function fullScreen(enabled: boolean): void
  export function toast(message: string): void
}
