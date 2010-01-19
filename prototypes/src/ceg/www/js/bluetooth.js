dojo.provide("humanapi.ceg.bluetooth");

humanapi.ceg.bluetooth = new function(){
	var 	cnt = 0,
		tmp = [],
		packets = [],
		packet = [],
		running = false,
		that = this
	;

	this.setHexData = function(val){
		tmp = val.split(":");
		for (var i=0, l=tmp.length; i<l; i++){
			if (tmp[i] == "0d"){
				// end of packet reached
				packets.push(that.toAscii(packet.join("")));
			}else if (tmp[i] == "0a"){
				// new packet
				packet = [];
				console.log("new packet");
			}else if(!running && tmp[i] != "0a" && tmp[i] != "0d"){
				packet = [];
				packet.push(tmp[i]);
			}else{
				// puth on stack
				packet.push(tmp[i]);
			}
			running = true;
		}

		// build current message string
		var strMsg = "", ecgTmpData = [];
		while (packets.length){
			str = packets.shift();
			console.log(str);
			dojo.publish("packet/new", [str]);
		}

	}

	// TODO: Hex to Ascii conversion, stolen from the web,
	// needs some cleanup
	var 	symbols = " !\"#$%&'()*+'-./0123456789:;<=>?@",
		loAZ = "abcdefghijklmnopqrstuvwxyz",
		valueStr
	;

	symbols+= loAZ.toUpperCase();
	symbols+= "[\\]^_`";
	symbols+= loAZ;
	symbols+= "{|}~";

	this.toAscii = function(val) {
		valueStr = val.toLowerCase();

		var 	hex = "0123456789abcdef",
			txt = "",
			char1,
			char2,
			num1,
			num2,
			value,
			valueInt,
			symbolIndex,
			ch
		;

		for( i=0, l=valueStr.length; i<l; i=i+2 ){
			char1 = valueStr.charAt(i);
			if ( char1 == ':' ){
				i++;
				char1 = valueStr.charAt(i);
			}
			char2 = valueStr.charAt(i+1);
			num1 = hex.indexOf(char1);
			num2 = hex.indexOf(char2);
			value = num1 << 4;
			value = value | num2;

			valueInt = parseInt(value);
			symbolIndex = valueInt - 32;
			ch = '?';
			if ( symbolIndex >= 0 && value <= 126 ){
				ch = symbols.charAt(symbolIndex)
			}
			txt += ch;
		}
		return txt;
	}
};

// Provide global setHexData for PhoneGap or other external layers
setHexData = humanapi.ceg.bluetooth.setHexData;