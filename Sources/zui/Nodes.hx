package zui;

@:access(zui.Zui)
class Nodes {

	public var nodeDrag:TNode = null;
	public var nodeSelected:TNode = null;
	public var panX = 0.0;
	public var panY = 0.0;
	var linkDrag:TNodeLink = null;
	var snapFromId = -1;
	var snapToId = -1;
	var snapSocket = 0;
	var snapX = 0.0;
	var snapY = 0.0;
	var SCALE = 1.0;
	var handle = new Zui.Handle();
	var lastNodesCount = 0;
	static var elementsBaked = false;
	static var socketImage: kha.Image = null;

	public function new() {}

	static inline var LINE_H = 22;
	function NODE_H(node:TNode):Int {
		var buttonsH = 0;
		for (but in node.buttons) {
			if (but.type == 'RGBA') buttonsH += 141;//buttonsH += 80;
			else buttonsH += LINE_H;
		}
		return LINE_H * 2 + node.inputs.length * LINE_H + node.outputs.length * LINE_H + buttonsH;
	}
	inline function NODE_W() { return 140; }
	inline function NODE_X(node:TNode) { return node.x + panX; }
	inline function NODE_Y(node:TNode) { return node.y + panY; }
	inline function SOCKET_Y(pos:Int):Int { return LINE_H * 2 + pos * LINE_H; }
	inline function p(f:Float):Int { return Std.int(f * SCALE); }

	function getNode(nodes: Array<TNode>, id: Int): TNode {
		for (node in nodes) if (node.id == id) return node;
		return null;
	}

	public function getNodeId(nodes: Array<TNode>): Int {
		var id = 0;
		for (n in nodes) if (n.id >= id) id = n.id + 1;
		return id;
	}

	function getLinkId(links: Array<TNodeLink>): Int {
		var id = 0;
		for (l in links) if (l.id >= id) id = l.id + 1;
		return id;
	}

	public function getSocketId(nodes: Array<TNode>): Int {
		var id = 0;
		for (n in nodes) {
			for (s in n.inputs) if (s.id >= id) id = s.id + 1;
			for (s in n.outputs) if (s.id >= id) id = s.id + 1;
		}
		return id;
	}

	function bakeElements(ui: Zui) {
		ui.g.end();
		elementsBaked = true;
		socketImage = kha.Image.createRenderTarget(20, 20);
		var g = socketImage.g2;
		g.begin(true, 0x00000000);
		g.color = 0xff000000;
		kha.graphics2.GraphicsExtension.fillCircle(g, 10, 10, 10);
		g.color = 0xffffffff;
		kha.graphics2.GraphicsExtension.fillCircle(g, 10, 10, 8);
		g.end();
		ui.g.begin(false);
	}

	public function nodeCanvas(ui: Zui, canvas: TNodeCanvas) {
		if (!elementsBaked) bakeElements(ui);
		if (lastNodesCount > canvas.nodes.length) ui.changed = true;
		lastNodesCount = canvas.nodes.length;

		SCALE = ui.ops.scaleFactor;
		var wx = ui._windowX;
		var wy = ui._windowY;

		// Pan cavas
		if (ui.inputDownR) { panX += ui.inputDX; panY += ui.inputDY; }

		for (link in canvas.links) {
			var from = getNode(canvas.nodes, link.from_id);
			var to = getNode(canvas.nodes, link.to_id);
			var fromX = from == null ? ui.inputX : wx + NODE_X(from) + NODE_W();
			var fromY = from == null ? ui.inputY : wy + NODE_Y(from) + SOCKET_Y(link.from_socket);
			var toX = to == null ? ui.inputX : wx + NODE_X(to);
			var toY = to == null ? ui.inputY : wy + NODE_Y(to) + SOCKET_Y(link.to_socket + to.outputs.length);

			// Snap to nearest socket
			if (linkDrag == link) {
				if (snapFromId != -1) { fromX = snapX; fromY = snapY; }
				if (snapToId != -1) { toX = snapX; toY = snapY; }
				snapFromId = snapToId = -1;

				for (node in canvas.nodes) {
					var inps = node.inputs;
					var outs = node.outputs;
					var nodeh = NODE_H(node);
					if (ui.getInputInRect(wx + NODE_X(node) - LINE_H / 2, wy + NODE_Y(node) - LINE_H / 2, NODE_W() + LINE_H, nodeh + LINE_H)) {
						// Snap to output
						if (from == null && node.id != to.id) {
							for (i in 0...outs.length) {
								var sx = wx + NODE_X(node) + NODE_W();
								var sy = wy + NODE_Y(node) + SOCKET_Y(i);
								if (ui.getInputInRect(sx - LINE_H / 2, sy - LINE_H / 2, LINE_H, LINE_H)) {
									snapX = sx;
									snapY = sy;
									snapFromId = node.id;
									snapSocket = i;
									break;
								}
							}
						}
						// Snap to input
						else if (to == null && node.id != from.id) {
							for (i in 0...inps.length) {
								var sx = wx + NODE_X(node) ;
								var sy = wy + NODE_Y(node) + SOCKET_Y(i + outs.length);
								if (ui.getInputInRect(sx - LINE_H / 2, sy - LINE_H / 2, LINE_H, LINE_H)) {
									snapX = sx;
									snapY = sy;
									snapToId = node.id;
									snapSocket = i;
									break;
								}
							}
						}
					}
				}
			}
			drawLink(ui, fromX - wx, fromY - wy, toX - wx, toY - wy);
		}

		for (node in canvas.nodes) {
			var inps = node.inputs;
			var outs = node.outputs;

			// Drag node
			var nodeh = NODE_H(node);
			if (ui.inputStarted && ui.getInputInRect(wx + NODE_X(node) - LINE_H / 2, wy + NODE_Y(node), NODE_W() + LINE_H, LINE_H)) {
				nodeDrag = node;
				nodeSelected = nodeDrag;
			}
			if (ui.inputStarted && ui.getInputInRect(wx + NODE_X(node) - LINE_H / 2, wy + NODE_Y(node) - LINE_H / 2, NODE_W() + LINE_H, nodeh + LINE_H)) {
				// Check sockets
				for (i in 0...outs.length) {
					var sx = wx + NODE_X(node) + NODE_W();
					var sy = wy + NODE_Y(node) + SOCKET_Y(i);
					if (ui.getInputInRect(sx - LINE_H / 2, sy - LINE_H / 2, LINE_H, LINE_H)) {
						// New link from output
						var l = { id: getLinkId(canvas.links), from_id: node.id, from_socket: i, to_id: -1, to_socket: -1 };
						canvas.links.push(l);
						linkDrag = l;
						break;
					}
				}
				if (linkDrag == null) {
					for (i in 0...inps.length) {
						var sx = wx + NODE_X(node);
						var sy = wy + NODE_Y(node) + SOCKET_Y(i + outs.length);
						if (ui.getInputInRect(sx - LINE_H / 2, sy - LINE_H / 2, LINE_H, LINE_H)) {
							// Already has a link - disconnect
							for (l in canvas.links) {
								if (l.to_id == node.id && l.to_socket == i) {
									l.to_id = l.to_socket = -1;
									linkDrag = l;
									break;
								}
							}
							if (linkDrag != null) break;
							// New link from input
							var l = { id: getLinkId(canvas.links), from_id: -1, from_socket: -1, to_id: node.id, to_socket: i };
							canvas.links.push(l);
							linkDrag = l;
							break;
						}
					}
				}
			}
			else if (ui.inputReleased) {
				// Connect to input
				if (snapToId != -1) {
					// Force single link per input
					for (l in canvas.links) {
						if (l.to_id == snapToId && l.to_socket == snapSocket) {
							canvas.links.remove(l);
							break;
						}
					}
					linkDrag.to_id = snapToId;
					linkDrag.to_socket = snapSocket;
					ui.changed = true;
				}
				// Connect to output
				else if (snapFromId != -1) {
					linkDrag.from_id = snapFromId;
					linkDrag.from_socket = snapSocket;
					ui.changed = true;
				}
				// Remove dragged link
				else if (linkDrag != null) {
					canvas.links.remove(linkDrag);
					ui.changed = true;
				}
				snapToId = snapFromId = -1;
				linkDrag = null;
				nodeDrag = null;
			}
			if (nodeDrag == node) {
				// handle.redraws = 2;
				node.x += Std.int(ui.inputDX);
				node.y += Std.int(ui.inputDY);
			}

			drawNode(ui, node);
		}
	}

	// Global enum mapping for now..
	public static var getEnumTexts:Void->Array<String> = null;
	public static var mapEnum:String->String = null;
	
	public function drawNode(ui: Zui, node: TNode) {
		var wx = ui._windowX;
		var wy = ui._windowY;
		var w = p(NODE_W());
		var g = ui.g;
		var h = p(NODE_H(node));
		var nx = p(NODE_X(node));
		var ny = p(NODE_Y(node));
		var text = node.name;
		var lineh = p(LINE_H);

		// Outline
		g.color = node == nodeSelected ? 0xffaaaaaa : 0xff202020;
		g.fillRect(nx - 1, ny - 1, w + 2, h + 2);

		// Header
		g.color = node.color;
		g.fillRect(nx, ny, w, lineh);

		// Title
		g.color = 0xffe7e7e7;
		g.font = ui.ops.font;
		g.fontSize = ui.fontSize;
		var textw = g.font.width(g.fontSize, text);
		g.drawString(text, nx + w / 2 - textw / 2, ny + 3);

		// Body
		ny += lineh;
		g.color = 0xff303030;
		g.fillRect(nx, ny, w, h - lineh);

		// Outputs
		for (out in node.outputs) {
			ny += lineh;
			g.color = out.color;
			// kha.graphics2.GraphicsExtension.fillCircle(g, nx + w, ny, 5);
			g.drawScaledImage(socketImage, nx + w - 5, ny - 5, 10, 10);
		}
		ny -= lineh * node.outputs.length;
		g.color = 0xffe7e7e7;
		for (out in node.outputs) {
			ny += lineh;
			var strw = ui.ops.font.width(ui.fontSize, out.name);
			g.drawString(out.name, nx + w - strw - 12, ny - 7);
		}

		// Buttons
		var nhandle = handle.nest(node.id);
		for (but in node.buttons) {

			if (but.type == 'RGBA') {
				ny += lineh; // 18 + 2 separator
				ui._x = nx;
				ui._y = ny;
				ui._w = w;
				
				var val = node.outputs[but.output].default_value;
				nhandle.r = val[0]; nhandle.g = val[1]; nhandle.b = val[2];
				Ext.colorWheel(ui, nhandle, false);
				val[0] = nhandle.r; val[1] = nhandle.g; val[2] = nhandle.b;
			}
			else if (but.type == 'VALUE') {
				ny += lineh;
				ui._x = nx;
				ui._y = ny;
				ui._w = w;
				var soc = node.outputs[but.output];
				soc.default_value = ui.slider(nhandle.nest(0, {value: soc.default_value}), "Value", 0.0, 1.0, true);
			}
			else if (but.type == 'STRING') {
				ny += lineh;
				ui._x = nx;
				ui._y = ny;
				ui._w = w;
				// TODO: Handle both color and alpha, .output to array?
				var soc = node.outputs[but.output];
				soc.default_value = but.default_value = ui.textInput(nhandle.nest(0, {text: soc.default_value}), "");
				ny += 10; // Fix align?
			}
			else if (but.type == 'ENUM') {
				ny += lineh;
				ui._x = nx;
				ui._y = ny;
				ui._w = w;
				var soc = node.outputs[but.output];
				var texts = getEnumTexts();
				but.default_value = ui.combo(nhandle.nest(0, {position: but.default_value}), texts, "Asset");
				soc.default_value = mapEnum(texts[but.default_value]);
				ny += 10; // Fix align?
			}
		}

		// Inputs
		for (inp in node.inputs) {
			ny += lineh;
			g.color = inp.color;
			g.drawScaledImage(socketImage, nx - 5, ny - 5, 10, 10);
		}
		ny -= lineh * node.inputs.length;
		g.color = 0xffe7e7e7;
		for (inp in node.inputs) {
			ny += lineh;
			g.drawString(inp.name, nx + 12, ny - 7);
		}
	}

	public function drawLink(ui: Zui, x1: Float, y1: Float, x2: Float, y2: Float) {
		var g = ui.g;
		g.color = 0xccadadad;
		// var curve = Math.min(Math.abs(y2 - y1) / 6.0, 40.0);
		// kha.graphics2.GraphicsExtension.drawCubicBezier(g, [x1, x1 + curve, x2 - curve, x2], [y1, y1 + curve, y2 - curve, y2], 20, 2.0);
		g.drawLine(p(x1), p(y1), p(x2), p(y2), 1.0);
		g.color = 0x99adadad;
		g.drawLine(p(x1) + 0.5, p(y1), p(x2) + 0.5, p(y2), 1.0);
		g.drawLine(p(x1) - 0.5, p(y1), p(x2) - 0.5, p(y2), 1.0);
		g.drawLine(p(x1), p(y1) + 0.5, p(x2), p(y2) + 0.5, 1.0);
		g.drawLine(p(x1), p(y1) - 0.5, p(x2), p(y2) - 0.5, 1.0);
		// g.color = 0x66adadad;
		// g.drawLine(p(x1) + 1.0, p(y1), p(x2) + 1.0, p(y2), 1.0);
		// g.drawLine(p(x1) - 1.0, p(y1), p(x2) - 1.0, p(y2), 1.0);
		// g.drawLine(p(x1), p(y1) + 1.0, p(x2), p(y2) + 1.0, 1.0);
		// g.drawLine(p(x1), p(y1) - 1.0, p(x2), p(y2) - 1.0, 1.0);
	}

	public function removeNode(n: TNode, canvas: TNodeCanvas) {
		var i = 0;      
		while (i < canvas.links.length) {
			var l = canvas.links[i];
			if (l.from_id == n.id || l.to_id == n.id) {
				canvas.links.splice(i, 1);
			}
			else i++;
		}
		canvas.nodes.remove(n);
	}
}

typedef TNodeCanvas = {
	var nodes: Array<TNode>;
	var links: Array<TNodeLink>;
}

typedef TNode = {
	var id: Int;
	var name: String;
	var type: String;
	var x: Float;
	var y: Float;
	var inputs: Array<TNodeSocket>;
	var outputs: Array<TNodeSocket>;
	var buttons: Array<TNodeButton>;
	var color: Int;
}

typedef TNodeSocket = {
	var id: Int;
	var node_id: Int;
	var name: String;
	var type: String;
	var default_value: Dynamic;
	var color: Int;
}

typedef TNodeLink = {
	var id: Int;
	var from_id: Int;
	var from_socket: Int;
	var to_id: Int;
	var to_socket: Int;
}

typedef TNodeButton = {
	var name: String;
	var type: String;
	var output: Int;
	@:optional var default_value: Dynamic;
}
