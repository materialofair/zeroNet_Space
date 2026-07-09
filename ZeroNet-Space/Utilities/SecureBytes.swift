//
//  SecureBytes.swift
//  ZeroNet-Space
//
//  引用语义的敏感字节容器
//  Data/Array 是写时复制（COW）值类型：对一个存在共享的值调用
//  withUnsafeMutableBytes 会先复制缓冲区，清零的只是副本，
//  原始明文仍留在内存中。这里用 class 独占持有字节、从不对外
//  暴露底层存储，保证清零发生在真正的缓冲区上。
//

import Foundation

/// 持有会话密码等敏感字节，置换或释放时就地清零
final class SecureBytes {

    private var storage: [UInt8]

    init(_ string: String) {
        self.storage = Array(string.utf8)
    }

    /// 以 String 形式读取（调用方仅在需要传递给加密接口时使用）
    var string: String? {
        String(bytes: storage, encoding: .utf8)
    }

    var isEmpty: Bool {
        storage.isEmpty
    }

    /// 就地清零。storage 从不对外暴露，引用唯一，不会触发 COW；
    /// 使用 memset_s 避免被编译器优化掉
    func wipe() {
        storage.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress, buffer.count > 0 else { return }
            _ = memset_s(baseAddress, buffer.count, 0, buffer.count)
        }
    }

    deinit {
        wipe()
    }
}
