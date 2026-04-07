import SwiftUI

// MARK: - Main Tackle View

struct TackleView: View {
    @EnvironmentObject var store: TackleStore

    var body: some View {
        NavigationStack {
            List {
                tackleSection(
                    title: "ロッド",
                    systemImage: "arrow.up.right",
                    count: store.rods.count,
                    destination: RodListView()
                )
                tackleSection(
                    title: "リール",
                    systemImage: "circle.circle",
                    count: store.reels.count,
                    destination: ReelListView()
                )
                tackleSection(
                    title: "ライン",
                    systemImage: "line.diagonal",
                    count: store.lines.count,
                    destination: LineListView()
                )
                tackleSection(
                    title: "ショックリーダー",
                    systemImage: "link",
                    count: store.leaders.count,
                    destination: LeaderListView()
                )
                tackleSection(
                    title: "ジグヘッド",
                    systemImage: "diamond.fill",
                    count: store.jigHeads.count,
                    destination: JigHeadListView()
                )
                tackleSection(
                    title: "ワーム",
                    systemImage: "waveform.path",
                    count: store.worms.count,
                    destination: WormListView()
                )
            }
            .listStyle(.insetGrouped)
            .navigationTitle("タックル管理")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private func tackleSection<D: View>(
        title: String, systemImage: String, count: Int, destination: D
    ) -> some View {
        NavigationLink(destination: destination.environmentObject(store)) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(.blue)
                    .frame(width: 28)
                Text(title)
                Spacer()
                Text("\(count)個")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Rod

struct RodListView: View {
    @EnvironmentObject var store: TackleStore
    @State private var showAdd = false

    var body: some View {
        List {
            ForEach(store.rods) { rod in
                NavigationLink(destination: RodEditView(rod: rod).environmentObject(store)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rod.displayName).font(.headline)
                        Text("\(rod.lengthLabel)  \(rod.lureWeightRange)  \(rod.lineWeightRange)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { store.delete(rod: $0) }
        }
        .navigationTitle("ロッド")
        .toolbar {
            EditButton()
            Button { showAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showAdd) {
            RodEditView(rod: nil).environmentObject(store)
        }
    }
}

struct RodEditView: View {
    @EnvironmentObject var store: TackleStore
    @Environment(\.dismiss) private var dismiss

    var rod: Rod?

    @State private var maker = ""
    @State private var name  = ""
    @State private var length = 6.0
    @State private var lureWeight = ""
    @State private var lineWeight = ""
    @State private var tip = Rod.TipType.solid
    @State private var memo  = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("メーカー・製品名") {
                    TextField("メーカー（例: ダイワ）", text: $maker)
                    TextField("製品名（例: 月下美人 AIR AGS 74L-S）", text: $name)
                }
                Section("スペック") {
                    HStack {
                        Text("長さ")
                        Spacer()
                        TextField("ft", value: $length, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                        Text("ft")
                    }
                    TextField("ルアーウェイト（例: 0.5〜5g）", text: $lureWeight)
                    TextField("ラインウェイト（例: PE 0.1〜0.4号）", text: $lineWeight)
                    Picker("ティップ", selection: $tip) {
                        ForEach(Rod.TipType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("メモ") {
                    TextEditor(text: $memo).frame(minHeight: 60)
                }
            }
            .navigationTitle(rod == nil ? "ロッドを追加" : "ロッドを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save(); dismiss() }
                        .disabled(maker.isEmpty || name.isEmpty)
                }
            }
            .onAppear {
                if let r = rod {
                    maker = r.maker; name = r.name; length = r.lengthFt
                    lureWeight = r.lureWeightRange; lineWeight = r.lineWeightRange
                    tip = r.tip; memo = r.memo
                }
            }
        }
    }

    private func save() {
        var r = rod ?? Rod(maker: "", name: "", lengthFt: 0, lureWeightRange: "", lineWeightRange: "")
        r.maker = maker; r.name = name; r.lengthFt = length
        r.lureWeightRange = lureWeight; r.lineWeightRange = lineWeight
        r.tip = tip; r.memo = memo
        rod == nil ? store.add(r) : store.update(r)
    }
}

// MARK: - Reel

struct ReelListView: View {
    @EnvironmentObject var store: TackleStore
    @State private var showAdd = false

    var body: some View {
        List {
            ForEach(store.reels) { reel in
                NavigationLink(destination: ReelEditView(reel: reel).environmentObject(store)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reel.displayName).font(.headline)
                        Text("ギア比 \(reel.gearRatio)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { store.delete(reel: $0) }
        }
        .navigationTitle("リール")
        .toolbar {
            EditButton()
            Button { showAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showAdd) {
            ReelEditView(reel: nil).environmentObject(store)
        }
    }
}

struct ReelEditView: View {
    @EnvironmentObject var store: TackleStore
    @Environment(\.dismiss) private var dismiss

    var reel: Reel?

    @State private var maker = ""
    @State private var name  = ""
    @State private var size  = ""
    @State private var gearRatio = ""
    @State private var memo  = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("メーカー・製品名") {
                    TextField("メーカー（例: シマノ）", text: $maker)
                    TextField("製品名（例: ソアレ BB）", text: $name)
                }
                Section("スペック") {
                    TextField("番手（例: 500, 1000S, 2000）", text: $size)
                    TextField("ギア比（例: 5.1:1）", text: $gearRatio)
                }
                Section("メモ") {
                    TextEditor(text: $memo).frame(minHeight: 60)
                }
            }
            .navigationTitle(reel == nil ? "リールを追加" : "リールを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save(); dismiss() }
                        .disabled(maker.isEmpty || name.isEmpty)
                }
            }
            .onAppear {
                if let r = reel {
                    maker = r.maker; name = r.name; size = r.size; gearRatio = r.gearRatio; memo = r.memo
                }
            }
        }
    }

    private func save() {
        var r = reel ?? Reel(maker: "", name: "", size: "", gearRatio: "")
        r.maker = maker; r.name = name; r.size = size; r.gearRatio = gearRatio; r.memo = memo
        reel == nil ? store.add(r) : store.update(r)
    }
}

// MARK: - Line

struct LineListView: View {
    @EnvironmentObject var store: TackleStore
    @State private var showAdd = false

    var body: some View {
        List {
            ForEach(store.lines) { line in
                NavigationLink(destination: LineEditView(line: line).environmentObject(store)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.displayName).font(.headline)
                        Text("\(line.lineType.rawValue)  \(line.lengthM)m")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { store.delete(line: $0) }
        }
        .navigationTitle("ライン")
        .toolbar {
            EditButton()
            Button { showAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showAdd) {
            LineEditView(line: nil).environmentObject(store)
        }
    }
}

struct LineEditView: View {
    @EnvironmentObject var store: TackleStore
    @Environment(\.dismiss) private var dismiss

    var line: FishingLine?

    @State private var maker      = ""
    @State private var name       = ""
    @State private var lineType   = FishingLine.LineType.esteron
    @State private var gauge      = ""
    @State private var strengthLb = 0.0
    @State private var lengthM    = 200
    @State private var memo       = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("メーカー・製品名") {
                    TextField("メーカー（例: サンライン）", text: $maker)
                    TextField("製品名（例: スモールゲームES-PE）", text: $name)
                }
                Section("スペック") {
                    Picker("種類", selection: $lineType) {
                        ForEach(FishingLine.LineType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    TextField("号数（例: 0.3号）", text: $gauge)
                    HStack {
                        Text("強度")
                        Spacer()
                        TextField("lb", value: $strengthLb, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                        Text("lb")
                    }
                    HStack {
                        Text("長さ")
                        Spacer()
                        TextField("m", value: $lengthM, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                        Text("m")
                    }
                }
                Section("メモ") {
                    TextEditor(text: $memo).frame(minHeight: 60)
                }
            }
            .navigationTitle(line == nil ? "ラインを追加" : "ラインを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save(); dismiss() }
                        .disabled(maker.isEmpty || name.isEmpty)
                }
            }
            .onAppear {
                if let l = line {
                    maker = l.maker; name = l.name; lineType = l.lineType
                    gauge = l.gauge; strengthLb = l.strengthLb; lengthM = l.lengthM; memo = l.memo
                }
            }
        }
    }

    private func save() {
        var l = line ?? FishingLine(maker: "", name: "", lineType: .esteron, gauge: "", lengthM: 200)
        l.maker = maker; l.name = name; l.lineType = lineType
        l.gauge = gauge; l.strengthLb = strengthLb; l.lengthM = lengthM; l.memo = memo
        line == nil ? store.add(l) : store.update(l)
    }
}

// MARK: - Leader

struct LeaderListView: View {
    @EnvironmentObject var store: TackleStore
    @State private var showAdd = false

    var body: some View {
        List {
            ForEach(store.leaders) { leader in
                NavigationLink(destination: LeaderEditView(leader: leader).environmentObject(store)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(leader.displayName).font(.headline)
                        Text("\(leader.lengthM)m")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { store.delete(leader: $0) }
        }
        .navigationTitle("ショックリーダー")
        .toolbar {
            EditButton()
            Button { showAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showAdd) {
            LeaderEditView(leader: nil).environmentObject(store)
        }
    }
}

struct LeaderEditView: View {
    @EnvironmentObject var store: TackleStore
    @Environment(\.dismiss) private var dismiss

    var leader: Leader?

    @State private var maker      = ""
    @State private var name       = ""
    @State private var gauge      = ""
    @State private var strengthLb = 0.0
    @State private var lengthM    = 50
    @State private var memo       = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("メーカー・製品名") {
                    TextField("メーカー（例: クレハ）", text: $maker)
                    TextField("製品名（例: シーガー グランドマックスFX）", text: $name)
                }
                Section("スペック") {
                    TextField("号数（例: 0.8号）", text: $gauge)
                    HStack {
                        Text("強度")
                        Spacer()
                        TextField("lb", value: $strengthLb, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                        Text("lb")
                    }
                    HStack {
                        Text("長さ")
                        Spacer()
                        TextField("m", value: $lengthM, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                        Text("m")
                    }
                }
                Section("メモ") {
                    TextEditor(text: $memo).frame(minHeight: 60)
                }
            }
            .navigationTitle(leader == nil ? "リーダーを追加" : "リーダーを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save(); dismiss() }
                        .disabled(maker.isEmpty || name.isEmpty)
                }
            }
            .onAppear {
                if let l = leader {
                    maker = l.maker; name = l.name
                    gauge = l.gauge; strengthLb = l.strengthLb; lengthM = l.lengthM; memo = l.memo
                }
            }
        }
    }

    private func save() {
        var l = leader ?? Leader(maker: "", name: "", gauge: "", lengthM: 50)
        l.maker = maker; l.name = name
        l.gauge = gauge; l.strengthLb = strengthLb; l.lengthM = lengthM; l.memo = memo
        leader == nil ? store.add(l) : store.update(l)
    }
}

// MARK: - JigHead

struct JigHeadListView: View {
    @EnvironmentObject var store: TackleStore
    @State private var showAdd = false

    var body: some View {
        List {
            ForEach(store.jigHeads) { jh in
                NavigationLink(destination: JigHeadEditView(jigHead: jh).environmentObject(store)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(jh.displayName).font(.headline)
                        if jh.quantity > 0 {
                            Text("在庫: \(jh.quantity)個")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { store.delete(jigHead: $0) }
        }
        .navigationTitle("ジグヘッド")
        .toolbar {
            EditButton()
            Button { showAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showAdd) {
            JigHeadEditView(jigHead: nil).environmentObject(store)
        }
    }
}

struct JigHeadEditView: View {
    @EnvironmentObject var store: TackleStore
    @Environment(\.dismiss) private var dismiss

    var jigHead: JigHead?

    @State private var maker    = ""
    @State private var name     = ""
    @State private var weight   = 0.5
    @State private var hookSize = ""
    @State private var quantity = 0
    @State private var memo     = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("メーカー・製品名") {
                    TextField("メーカー（例: ライトニングストライク）", text: $maker)
                    TextField("製品名（例: 尺ヘッドR）", text: $name)
                }
                Section("スペック") {
                    HStack {
                        Text("ウェイト")
                        Spacer()
                        TextField("g", value: $weight, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                        Text("g")
                    }
                    TextField("フックサイズ（例: #6, #8）", text: $hookSize)
                    Stepper("在庫: \(quantity)個", value: $quantity, in: 0...999)
                }
                Section("メモ") {
                    TextEditor(text: $memo).frame(minHeight: 60)
                }
            }
            .navigationTitle(jigHead == nil ? "ジグヘッドを追加" : "ジグヘッドを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save(); dismiss() }
                        .disabled(maker.isEmpty || name.isEmpty)
                }
            }
            .onAppear {
                if let jh = jigHead {
                    maker = jh.maker; name = jh.name; weight = jh.weight
                    hookSize = jh.hookSize; quantity = jh.quantity; memo = jh.memo
                }
            }
        }
    }

    private func save() {
        var jh = jigHead ?? JigHead(maker: "", name: "", weight: 0.5, hookSize: "")
        jh.maker = maker; jh.name = name; jh.weight = weight
        jh.hookSize = hookSize; jh.quantity = quantity; jh.memo = memo
        jigHead == nil ? store.add(jh) : store.update(jh)
    }
}

// MARK: - Worm

struct WormListView: View {
    @EnvironmentObject var store: TackleStore
    @State private var showAdd = false

    var body: some View {
        List {
            ForEach(store.worms) { worm in
                NavigationLink(destination: WormEditView(worm: worm).environmentObject(store)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(worm.displayName).font(.headline)
                        Text(worm.lengthLabel)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { store.delete(worm: $0) }
        }
        .navigationTitle("ワーム")
        .toolbar {
            EditButton()
            Button { showAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showAdd) {
            WormEditView(worm: nil).environmentObject(store)
        }
    }
}

struct WormEditView: View {
    @EnvironmentObject var store: TackleStore
    @Environment(\.dismiss) private var dismiss

    var worm: Worm?

    @State private var maker  = ""
    @State private var name   = ""
    @State private var length = 1.5
    @State private var color  = ""
    @State private var memo   = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("メーカー・製品名") {
                    TextField("メーカー（例: バークレイ）", text: $maker)
                    TextField("製品名（例: アジリンガー）", text: $name)
                }
                Section("スペック") {
                    HStack {
                        Text("サイズ")
                        Spacer()
                        TextField("inch", value: $length, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                        Text("inch")
                    }
                    TextField("カラー（例: グロー / チャートクリア）", text: $color)
                }
                Section("メモ") {
                    TextEditor(text: $memo).frame(minHeight: 60)
                }
            }
            .navigationTitle(worm == nil ? "ワームを追加" : "ワームを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save(); dismiss() }
                        .disabled(maker.isEmpty || name.isEmpty)
                }
            }
            .onAppear {
                if let w = worm {
                    maker = w.maker; name = w.name; length = w.lengthInch; color = w.color; memo = w.memo
                }
            }
        }
    }

    private func save() {
        var w = worm ?? Worm(maker: "", name: "", lengthInch: 1.5, color: "")
        w.maker = maker; w.name = name; w.lengthInch = length; w.color = color; w.memo = memo
        worm == nil ? store.add(w) : store.update(w)
    }
}
