# Contributing to BooruNova

感谢你愿意为 BooruNova 贡献！/ Thanks for contributing to BooruNova!

## 报告问题 / Reporting Issues

提交 issue 时请包含：

- 复现步骤（越具体越好）
- 涉及的站点/引擎（如 Danbooru、e621、Rule34…）
- 应用版本号（设置 → 关于）
- 设备型号与 Android 版本

## 贡献代码 / Contributing Code

1. **Fork** 仓库，基于 `main` 新建分支
2. 改动前先跑基线验证：

   ```bash
   flutter pub get
   flutter analyze          # 必须 0 issue
   flutter test             # 必须全绿
   ```

3. 新增引擎时，遵循现有结构：

   - 继承 `BaseBooruRepository`（`lib/boorus/engine/base_booru_repository.dart`）
   - 在 `lib/boorus/engine/registry.dart` 注册
   - 为 parser 补 fixture 驱动的单测（`test/boorus/`）

4. 提交信息用 `type(scope): 描述` 格式（参考已有提交历史）
5. 推分支并发起 Pull Request

## 提交规范 / Commit Conventions

| 类型 | 用途 |
|------|------|
| `feat` | 新功能 |
| `fix` | 修复 bug |
| `perf` | 性能优化 |
| `refactor` | 重构（无行为变化） |
| `docs` | 文档 |
| `chore` | 构建/版本号等杂项 |

## 行为准则 / Code of Conduct

保持友善与专业。请勿提交侵犯版权的图片资源或任何恶意代码。
