import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

struct CommunityView: View {
    @ObservedObject private var account = CommunityAccountStore.shared
    @StateObject private var board = CommunityMessageStore()
    @AppStorage("dashboardSportThemeEnabled") private var sportMode = false
    @State private var draft = ""
    @State private var nickname = ""
    @State private var leaderboardVisible = true
    @State private var isSavingProfile = false

    private var palette: CommunityPalette { CommunityPalette(sportMode: sportMode) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 280), spacing: 14),
                    GridItem(.flexible(minimum: 280), spacing: 14),
                ],
                alignment: .leading,
                spacing: 14
            ) {
                accountPanel
                leaderboardPanel
            }

            discussionPanel
        }
        .task {
            await account.refreshLeaderboard()
            await board.refresh()
            syncProfile()
        }
        .onChange(of: account.account?.id) { _ in
            syncProfile()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.16))
                Image(systemName: "person.2.fill")
                    .font(.title3)
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text("用户交流 / Community")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.text)
                Text("CodexPilot 用户社区，交流本机监控与 Codex 使用体验 / A shared room for CodexPilot users")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            Button {
                Task {
                    await account.refreshLeaderboard()
                    await board.refresh()
                }
            } label: {
                Label("刷新 / Refresh", systemImage: "arrow.clockwise")
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(board.isLoading)
        }
        .padding(14)
        .background(palette.carbon, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(palette.hairline, lineWidth: 1))
    }

    private var accountPanel: some View {
        CommunityPanel(
            title: "Lynncat 账户 / Account",
            subtitle: "登录、在线积分与公开资料 / Sign in, points & profile",
            palette: palette
        ) {
            if account.isRestoring {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在恢复账户 / Restoring account")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
            } else if let user = account.account, account.isAuthenticated {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 10) {
                        CommunityAvatar(name: user.nickname, tint: palette.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.nickname)
                                .font(.headline)
                                .foregroundStyle(palette.text)
                            Text(account.isAccruing ? "在线积分累计中 / Earning while active" : "积分暂停 / Points paused")
                                .font(.caption2)
                                .foregroundStyle(account.isAccruing ? palette.green : palette.secondaryText)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(user.pointsBalance)")
                                .font(.title2.monospacedDigit())
                                .fontWeight(.bold)
                                .foregroundStyle(palette.amber)
                            Text("积分 / Points")
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryText)
                        }
                    }

                    Divider()

                    HStack(spacing: 8) {
                        TextField("昵称 / Nickname", text: $nickname)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(saveProfile)
                        Button(action: saveProfile) {
                            Image(systemName: "checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(palette.accent)
                        .disabled(isSavingProfile || nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .help("保存资料 / Save profile")
                    }

                    Toggle("在排行榜公开昵称和积分 / Show profile on leaderboard", isOn: $leaderboardVisible)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                        .toggleStyle(.switch)
                        .onChange(of: leaderboardVisible) { _ in
                            guard leaderboardVisible != account.account?.leaderboardVisible else { return }
                            saveProfile()
                        }

                    HStack {
                        Label("在线 \(account.activeSeconds / 60) 分钟 / Active \(account.activeSeconds / 60)m", systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryText)
                        Spacer()
                        Button(role: .destructive, action: account.logout) {
                            Label("退出 / Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("登录后，应用保持运行时可累计积分；每次发言消耗 3 积分。")
                        .font(.callout)
                        .foregroundStyle(palette.text)
                    Text("Sign in to earn points while CodexPilot is active and join the discussion.")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                    CommunitySignInButton(tint: palette.accent)
                }
            }

            if let error = account.errorText {
                CommunityFeedback(text: error, tint: .red, palette: palette)
            }
        }
    }

    private var leaderboardPanel: some View {
        CommunityPanel(
            title: "积分排名 / Points Leaderboard",
            subtitle: "公开资料才会显示 / Public profiles only",
            palette: palette
        ) {
            if account.leaderboard.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    if account.isRestoring {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("暂时没有公开排名 / No public rankings yet")
                            .font(.callout)
                            .foregroundStyle(palette.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
            } else {
                VStack(spacing: 7) {
                    ForEach(account.leaderboard.prefix(5)) { entry in
                        leaderboardRow(entry)
                    }
                }
            }
        }
    }

    private var discussionPanel: some View {
        CommunityPanel(
            title: "CodexPilot 交流室 / Discussion",
            subtitle: "每次发言 3 积分；请勿发布链接、联系方式或敏感信息 / 3 points per post; keep it safe and useful",
            palette: palette
        ) {
            VStack(alignment: .leading, spacing: 12) {
                composer

                if let feedback = board.feedback {
                    CommunityFeedback(text: feedback, tint: palette.amber, palette: palette)
                }

                if board.isLoading && board.visibleMessages.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("正在加载交流内容 / Loading discussion")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                } else if board.visibleMessages.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.title2)
                            .foregroundStyle(palette.secondaryText)
                        Text("还没有留言，来发第一条吧 / No posts yet")
                            .font(.callout)
                            .foregroundStyle(palette.secondaryText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(board.visibleMessages) { message in
                            messageRow(message)
                        }
                    }
                }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $draft)
                .font(.callout)
                .foregroundStyle(palette.text)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 72, maxHeight: 108)
                .background(palette.raised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(palette.hairline, lineWidth: 1))
                .onChange(of: draft) { value in
                    if value.count > 200 { draft = String(value.prefix(200)) }
                }

            HStack {
                Text("\(draft.count)/200 · 3 积分 / 3 points")
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryText)
                Spacer()
                Button {
                    Task {
                        if await board.send(draft) {
                            draft = ""
                            await account.refreshLeaderboard()
                        }
                    }
                } label: {
                    Label(board.isPosting ? "发送中 / Sending" : "发送留言 / Post", systemImage: "paperplane.fill")
                        .lineLimit(1)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
                .controlSize(.small)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || board.isPosting)
            }
        }
    }

    private func leaderboardRow(_ entry: CommunityLeaderboardEntry) -> some View {
        HStack(spacing: 10) {
            Text("\(entry.rank)")
                .font(.caption.monospacedDigit())
                .fontWeight(.bold)
                .foregroundStyle(entry.rank <= 3 ? palette.amber : palette.secondaryText)
                .frame(width: 20, alignment: .leading)
            CommunityAvatar(name: entry.nickname, tint: entry.isCurrentUser ? palette.accent : palette.green, size: 25)
            Text(entry.nickname)
                .font(.callout)
                .fontWeight(entry.isCurrentUser ? .semibold : .regular)
                .foregroundStyle(palette.text)
                .lineLimit(1)
            Spacer()
            Text("\(entry.pointsBalance)")
                .font(.callout.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(palette.amber)
        }
        .padding(.vertical, 3)
    }

    private func messageRow(_ message: CommunityMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            CommunityAvatar(name: message.displayName, tint: palette.green, size: 30)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(message.displayName)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(palette.text)
                    Text(message.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryText)
                    Spacer(minLength: 0)
                    Menu {
                        Menu("举报 / Report") {
                            ForEach(CommunityReportReason.allCases) { reason in
                                Button(reason.label) {
                                    Task { await board.report(message, reason: reason) }
                                }
                            }
                        }
                        Button("屏蔽此用户 / Block user", role: .destructive) {
                            board.block(message.authorKey)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 18)
                }
                Text(message.text)
                    .font(.callout)
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(palette.raised.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(palette.hairline, lineWidth: 1))
    }

    private func saveProfile() {
        guard !isSavingProfile else { return }
        let trimmedName = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard trimmedName != account.account?.nickname || leaderboardVisible != account.account?.leaderboardVisible else { return }
        isSavingProfile = true
        let name = trimmedName
        let visible = leaderboardVisible
        Task {
            await account.updateProfile(nickname: name, leaderboardVisible: visible)
            isSavingProfile = false
        }
    }

    private func syncProfile() {
        nickname = account.account?.nickname ?? ""
        leaderboardVisible = account.account?.leaderboardVisible ?? true
    }
}

private struct CommunitySignInButton: View {
    @ObservedObject private var account = CommunityAccountStore.shared
    var tint: Color
    @State private var nonce = ""
    @State private var feedback: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SignInWithAppleButton(.continue) { request in
                nonce = makeNonce()
                request.requestedScopes = []
                request.nonce = sha256(nonce)
            } onCompletion: { result in
                handle(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(maxWidth: 230, minHeight: 38)
            .disabled(account.isSigningIn)

            if account.isSigningIn {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("正在登录 / Signing in")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let feedback {
                Text(feedback)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        guard case let .success(authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityData = credential.identityToken,
              let authorizationData = credential.authorizationCode,
              let identityToken = String(data: identityData, encoding: .utf8),
              let authorizationCode = String(data: authorizationData, encoding: .utf8) else {
            feedback = "Apple 登录未完成，请重试 / Sign in was not completed"
            return
        }
        guard !account.isSigningIn else { return }
        Task { @MainActor in
            do {
                try await account.signIn(CommunityAppleCredential(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    nonce: nonce,
                    installationId: CommunityInstallationID.current,
                    platform: "macos"
                ))
                feedback = nil
            } catch {
                feedback = signInFeedback(for: error)
            }
        }
    }

    private func signInFeedback(for error: Error) -> String {
        switch error {
        case CommunityServiceError.requestTimedOut:
            return "登录请求超时，请检查网络后重试 / Sign-in timed out. Check your connection and try again"
        case let CommunityServiceError.server(statusCode, code):
            return "服务拒绝登录（\(statusCode): \(code)）/ Sign-in rejected (\(statusCode): \(code))"
        case CommunityServiceError.keychain:
            return "无法保存登录会话，请检查钥匙串访问权限 / Could not save the session to Keychain"
        case CommunityServiceError.transport:
            return "无法连接账户服务，请检查网络 / Could not connect to the account service"
        default:
            return "登录失败，请稍后重试 / Could not sign in"
        }
    }

    private func makeNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            return UUID().uuidString.lowercased()
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private struct CommunityPanel<Content: View>: View {
    var title: String
    var subtitle: String
    var palette: CommunityPalette
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(palette.text)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(2)
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(palette.hairline, lineWidth: 1))
    }
}

private struct CommunityAvatar: View {
    var name: String
    var tint: Color
    var size: CGFloat = 34

    var body: some View {
        Text(String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased())
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.15), in: Circle())
    }
}

private struct CommunityFeedback: View {
    var text: String
    var tint: Color
    var palette: CommunityPalette

    var body: some View {
        Label(text, systemImage: "info.circle.fill")
            .font(.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct CommunityPalette {
    var sportMode: Bool

    var panel: Color { sportMode ? Color(red: 0.085, green: 0.088, blue: 0.096) : Color.white.opacity(0.88) }
    var raised: Color { sportMode ? Color(red: 0.125, green: 0.128, blue: 0.138) : Color(red: 0.945, green: 0.952, blue: 0.965) }
    var carbon: Color { sportMode ? Color(red: 0.020, green: 0.022, blue: 0.026) : Color(red: 0.925, green: 0.935, blue: 0.950) }
    var text: Color { sportMode ? Color.white.opacity(0.92) : Color(red: 0.105, green: 0.115, blue: 0.130) }
    var secondaryText: Color { sportMode ? Color.white.opacity(0.58) : Color(red: 0.390, green: 0.420, blue: 0.460) }
    var hairline: Color { sportMode ? Color.white.opacity(0.12) : Color.black.opacity(0.12) }
    var accent: Color { sportMode ? Color(red: 0.91, green: 0.06, blue: 0.045) : .accentColor }
    var green: Color { Color(red: 0.12, green: 0.84, blue: 0.34) }
    var amber: Color { Color(red: 1.0, green: 0.58, blue: 0.12) }
}
