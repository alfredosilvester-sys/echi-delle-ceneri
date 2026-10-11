import SwiftUI
import SpriteKit

@main
struct EchiDelleCeneriApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }
}

struct GameView: View {
    @State private var scene = AshesScene(size: CGSize(width: 900, height: 500))

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("ECHI DELLE CENERI")
                                .font(.system(size: 12, weight: .black, design: .serif))
                                .tracking(2)
                                .foregroundStyle(Color(red: 0.82, green: 0.72, blue: 0.52))
                            HStack(spacing: 3) {
                                ForEach(0..<5, id: \.self) { i in
                                    Capsule().fill(i < scene.playerHealth ? Color.red.opacity(0.9) : Color.gray.opacity(0.25))
                                        .frame(width: 25, height: 6)
                                }
                            }
                            Text("Cavaliere senza nome  •  Rovine di Eldraen")
                                .font(.system(size: 10, weight: .medium, design: .serif))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        Spacer()
                        Button {
                            scene.restart()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.black.opacity(0.55), in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    Spacer()
                    HStack(alignment: .bottom) {
                        HStack(spacing: 10) {
                            control("chevron.left") { scene.setMove(-1) }
                                .onLongPressGesture(minimumDuration: 0.08, pressing: { pressing in
                                    scene.setMove(pressing ? -1 : 0)
                                }, perform: {})
                            control("chevron.right") { scene.setMove(1) }
                                .onLongPressGesture(minimumDuration: 0.08, pressing: { pressing in
                                    scene.setMove(pressing ? 1 : 0)
                                }, perform: {})
                        }
                        Spacer()
                        HStack(spacing: 12) {
                            action("SALTO", symbol: "arrow.up") { scene.jump() }
                            action("ATTACCO", symbol: "burst.fill") { scene.attack() }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, max(geo.safeAreaInsets.bottom, 12))
                }
            }
            .background(Color.black)
        }
    }

    private func control(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .heavy))
                .frame(width: 58, height: 58)
                .background(.black.opacity(0.6), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.24), lineWidth: 1))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func action(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 19, weight: .black))
                Text(title).font(.system(size: 8, weight: .black, design: .rounded)).tracking(1)
            }
            .frame(width: 62, height: 62)
            .background(title == "ATTACCO" ? Color(red: 0.38, green: 0.12, blue: 0.10).opacity(0.9) : .black.opacity(0.65), in: Circle())
            .overlay(Circle().stroke(title == "ATTACCO" ? Color.red.opacity(0.6) : .white.opacity(0.25), lineWidth: 1))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

final class AshesScene: SKScene, SKPhysicsContactDelegate {
    private let player = SKNode()
    private let bodyShape = SKShapeNode(rectOf: CGSize(width: 25, height: 48), cornerRadius: 5)
    private let sword = SKShapeNode(rectOf: CGSize(width: 34, height: 4), cornerRadius: 2)
    private var enemy: SKNode!
    private var enemyHealth = 3
    private var moveDirection: CGFloat = 0
    private var facing: CGFloat = 1
    private var isAttacking = false
    private var isInvulnerable = false
    private var lastUpdate: TimeInterval = 0
    private var lastEnemyAttack: TimeInterval = 0
    private var world: SKNode!
    private var cameraNode = SKCameraNode()
    var playerHealth = 5
    private var healthCallbackTimer: TimeInterval = 0

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.035, green: 0.045, blue: 0.06, alpha: 1)
        physicsWorld.gravity = CGVector(dx: 0, dy: -18)
        physicsWorld.contactDelegate = self
        buildWorld()
    }

    func buildWorld() {
        removeAllChildren()
        world = SKNode()
        addChild(world)
        addChild(cameraNode)
        camera = cameraNode

        // Moon and layered silhouettes
        let moon = SKShapeNode(circleOfRadius: 38)
        moon.fillColor = SKColor(red: 0.72, green: 0.69, blue: 0.58, alpha: 0.65)
        moon.strokeColor = .clear
        moon.position = CGPoint(x: 260, y: 280)
        world.addChild(moon)

        for i in 0..<12 {
            let x = CGFloat(i) * 100 - 100
            let tower = SKShapeNode(rectOf: CGSize(width: CGFloat(24 + (i % 3) * 14), height: CGFloat(100 + (i % 4) * 26)))
            tower.fillColor = SKColor(red: 0.07, green: 0.08, blue: 0.105, alpha: 1)
            tower.strokeColor = .clear
            tower.position = CGPoint(x: x, y: 120 + CGFloat((i % 3) * 7))
            world.addChild(tower)
            let spire = SKShapeNode(path: {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: -20, y: 0)); p.addLine(to: CGPoint(x: 0, y: 28)); p.addLine(to: CGPoint(x: 20, y: 0)); p.closeSubpath()
                return p
            }())
            spire.fillColor = tower.fillColor
            spire.strokeColor = .clear
            spire.position = CGPoint(x: x, y: tower.position.y + CGFloat(60 + (i % 4) * 26))
            world.addChild(spire)
        }

        // Ground
        let ground = SKNode()
        ground.position = CGPoint(x: 0, y: 40)
        ground.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 2400, height: 60))
        ground.physicsBody?.isDynamic = false
        ground.physicsBody?.categoryBitMask = 1
        world.addChild(ground)
        let groundArt = SKShapeNode(rectOf: CGSize(width: 2400, height: 60))
        groundArt.fillColor = SKColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1)
        groundArt.strokeColor = SKColor(red: 0.37, green: 0.31, blue: 0.24, alpha: 1)
        groundArt.lineWidth = 2
        ground.addChild(groundArt)
        for i in 0..<48 {
            let crack = SKShapeNode()
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -9, y: 0)); p.addLine(to: CGPoint(x: 0, y: -5)); p.addLine(to: CGPoint(x: 6, y: -2))
            crack.path = p
            crack.strokeColor = .black.withAlphaComponent(0.45)
            crack.lineWidth = 1
            crack.position = CGPoint(x: CGFloat(i) * 50 - 1180, y: 12)
            ground.addChild(crack)
        }

        // Small floating ruin platform
        let ledge = SKNode()
        ledge.position = CGPoint(x: 420, y: 150)
        ledge.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 120, height: 18))
        ledge.physicsBody?.isDynamic = false
        world.addChild(ledge)
        let ledgeArt = SKShapeNode(rectOf: CGSize(width: 120, height: 18))
        ledgeArt.fillColor = SKColor(red: 0.23, green: 0.21, blue: 0.20, alpha: 1)
        ledgeArt.strokeColor = .clear
        ledge.addChild(ledgeArt)

        makePlayer()
        makeEnemy(at: CGPoint(x: 230, y: 105))
        cameraNode.position = CGPoint(x: 0, y: size.height / 2)
        addAtmosphere()
    }

    private func addAtmosphere() {
        for i in 0..<34 {
            let ember = SKShapeNode(circleOfRadius: CGFloat((i % 3) + 1))
            ember.fillColor = SKColor(red: 0.68, green: 0.29, blue: 0.12, alpha: 0.45)
            ember.strokeColor = .clear
            ember.position = CGPoint(x: CGFloat((i * 79) % 1000) - 100, y: CGFloat((i * 37) % 280) + 60)
            let drift = SKAction.sequence([
                SKAction.moveBy(x: CGFloat((i % 2 == 0) ? 24 : -20), y: CGFloat(20 + i % 35), duration: 2.4 + Double(i % 4)),
                SKAction.moveBy(x: CGFloat((i % 2 == 0) ? -24 : 20), y: CGFloat(-20 - i % 35), duration: 2.4 + Double(i % 4))
            ])
            ember.run(.repeatForever(drift))
            world.addChild(ember)
        }
    }

    private func makePlayer() {
        player.removeAllChildren()
        player.position = CGPoint(x: 0, y: 110)
        player.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 23, height: 43))
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.restitution = 0
        player.physicsBody?.friction = 0.7
        player.physicsBody?.linearDamping = 0.1
        player.physicsBody?.categoryBitMask = 2
        player.physicsBody?.collisionBitMask = 1
        player.physicsBody?.mass = 0.8

        bodyShape.fillColor = SKColor(red: 0.18, green: 0.20, blue: 0.23, alpha: 1)
        bodyShape.strokeColor = SKColor(red: 0.66, green: 0.55, blue: 0.36, alpha: 1)
        bodyShape.lineWidth = 1.5
        bodyShape.position = CGPoint(x: 0, y: 1)
        player.addChild(bodyShape)

        let helmet = SKShapeNode(circleOfRadius: 10)
        helmet.fillColor = SKColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1)
        helmet.strokeColor = SKColor(red: 0.70, green: 0.57, blue: 0.34, alpha: 1)
        helmet.lineWidth = 1.5
        helmet.position = CGPoint(x: 0, y: 19)
        player.addChild(helmet)

        let visor = SKShapeNode(rectOf: CGSize(width: 12, height: 3))
        visor.fillColor = SKColor(red: 0.70, green: 0.12, blue: 0.08, alpha: 1)
        visor.strokeColor = .clear
        visor.position = CGPoint(x: 2, y: 18)
        player.addChild(visor)

        sword.fillColor = SKColor(red: 0.75, green: 0.73, blue: 0.65, alpha: 1)
        sword.strokeColor = .clear
        sword.position = CGPoint(x: 20, y: 1)
        player.addChild(sword)
        world.addChild(player)
    }

    private func makeEnemy(at point: CGPoint) {
        enemy = SKNode()
        enemy.position = point
        enemy.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 30, height: 48))
        enemy.physicsBody?.isDynamic = false
        enemy.physicsBody?.allowsRotation = false
        enemy.physicsBody?.categoryBitMask = 4
        let torso = SKShapeNode(rectOf: CGSize(width: 30, height: 48), cornerRadius: 5)
        torso.fillColor = SKColor(red: 0.25, green: 0.07, blue: 0.08, alpha: 1)
        torso.strokeColor = SKColor(red: 0.58, green: 0.20, blue: 0.15, alpha: 1)
        torso.lineWidth = 2
        enemy.addChild(torso)
        let eyes = SKShapeNode(rectOf: CGSize(width: 13, height: 3))
        eyes.fillColor = .red
        eyes.strokeColor = .clear
        eyes.position = CGPoint(x: 0, y: 9)
        enemy.addChild(eyes)
        let blade = SKShapeNode(rectOf: CGSize(width: 25, height: 4))
        blade.fillColor = .lightGray
        blade.strokeColor = .clear
        blade.position = CGPoint(x: 18, y: -3)
        enemy.addChild(blade)
        world.addChild(enemy)
    }

    func setMove(_ direction: CGFloat) { moveDirection = direction }
    func jump() {
        guard let body = player.physicsBody, abs(body.velocity.dy) < 1.5 else { return }
        body.applyImpulse(CGVector(dx: 0, dy: 390))
    }
    func attack() {
        guard !isAttacking else { return }
        isAttacking = true
        sword.fillColor = .white
        sword.run(.sequence([
            .group([.rotate(byAngle: facing > 0 ? -1.5 : 1.5, duration: 0.09),
                    .moveBy(x: facing * 17, y: 4, duration: 0.09)]),
            .run { [weak self] in self?.checkHit() },
            .group([.rotate(byAngle: facing > 0 ? 1.5 : -1.5, duration: 0.12),
                    .moveBy(x: -facing * 17, y: -4, duration: 0.12)]),
            .run { [weak self] in
                self?.isAttacking = false
                self?.sword.fillColor = SKColor(red: 0.75, green: 0.73, blue: 0.65, alpha: 1)
            }
        ]))
    }

    private func checkHit() {
        guard let enemy = enemy, enemy.parent != nil else { return }
        let distance = abs(enemy.position.x - player.position.x)
        if distance < 68 && abs(enemy.position.y - player.position.y) < 85 {
            enemyHealth -= 1
            enemy.run(.sequence([
                .moveBy(x: facing * 13, y: 0, duration: 0.06),
                .moveBy(x: -facing * 13, y: 0, duration: 0.08)
            ]))
            let flash = SKShapeNode(circleOfRadius: 20)
            flash.fillColor = SKColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 0.55)
            flash.strokeColor = .clear
            flash.position = enemy.position
            world.addChild(flash)
            flash.run(.sequence([.fadeOut(withDuration: 0.22), .removeFromParent()]))
            if enemyHealth <= 0 {
                enemy.run(.sequence([.fadeOut(withDuration: 0.35), .removeFromParent()]))
                self.enemy = nil
                showMessage("IL CUSTODE È CADUTO")
            }
        }
    }

    private func showMessage(_ message: String) {
        let label = SKLabelNode(fontNamed: "Georgia-Bold")
        label.text = message
        label.fontSize = 17
        label.fontColor = SKColor(red: 0.83, green: 0.69, blue: 0.42, alpha: 1)
        label.position = CGPoint(x: cameraNode.position.x, y: size.height * 0.68)
        label.zPosition = 100
        addChild(label)
        label.run(.sequence([.wait(forDuration: 2), .fadeOut(withDuration: 0.7), .removeFromParent()]))
    }

    func restart() {
        playerHealth = 5
        enemyHealth = 3
        moveDirection = 0
        isAttacking = false
        buildWorld()
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 1.0 / 20.0)
        lastUpdate = currentTime
        guard let body = player.physicsBody else { return }
        body.velocity.dx = moveDirection * 210
        if moveDirection != 0 {
            facing = moveDirection > 0 ? 1 : -1
            player.xScale = facing
        }
        let targetX = max(0, min(player.position.x, 760))
        cameraNode.position.x += (targetX - cameraNode.position.x) * min(1, dt * 4)
        cameraNode.position.y = size.height / 2

        if let enemy = enemy, enemy.parent != nil {
            let dx = player.position.x - enemy.position.x
            if abs(dx) < 210 && abs(dx) > 38 {
                enemy.position.x += (dx > 0 ? 1 : -1) * 58 * dt
            }
            if abs(dx) < 42 && currentTime - lastEnemyAttack > 1.5 && !isInvulnerable {
                lastEnemyAttack = currentTime
                playerHealth = max(0, playerHealth - 1)
                isInvulnerable = true
                player.alpha = 0.45
                player.run(.sequence([
                    .wait(forDuration: 0.65),
                    .run { [weak self] in self?.isInvulnerable = false; self?.player.alpha = 1 }
                ]))
                if playerHealth == 0 {
                    showMessage("SEI CADUTO NELLE CENERI")
                    moveDirection = 0
                }
            }
        }
    }
}
