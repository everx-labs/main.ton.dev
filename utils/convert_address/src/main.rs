// Copyright 2020 TON DEV SOLUTIONS LTD.
//
// Licensed under the SOFTWARE EVALUATION License (the "License"); you may not use
// this file except in compliance with the License.  You may obtain a copy of the
// License at:
//
// https://www.ton.dev/licenses
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific TON DEV software governing permissions and limitations
// under the License.

use std::convert::TryFrom;

struct Address {
    workchain: i8,
    account_id: Vec<u8>
}
impl Address {
    fn decode_std_base64(data: &str) -> Result<Self, String> {
        // conversion from base64url
        let data = data.replace('_', "/").replace('-', "+");

        let vec = base64::decode(&data)
            .map_err(|err| format!("Couldn't parse base64: {}", err))?;

        // check CRC and address tag
        let mut crc = crc_any::CRC::crc16xmodem();
        crc.digest(&vec[..34]);

        if crc.get_crc_vec_be() != &vec[34..36] {
            return Err(format!("base64 address invalid CRC \"{}\"", data));
        };

        if vec[0] & 0x3f != 0x11 {
            return Err(format!("base64 address invalid tag \"{}\"", data));
        }

        Ok(Address{
            workchain: i8::from_be_bytes(<[u8; 1]>::try_from(&vec[1..2]).unwrap()),
            account_id: vec[2..34].to_vec()
        })
    }

    fn decode_std_hex(data: &str) -> Result<Self, String> {
        let vec: Vec<&str> = data.split(':').collect();

        if vec.len() != 2 {
            return Err(format!("Malformed std hex address. No \":\" delimiter. \"{}\"", data));
        }

        if vec[1].len() != 64 {
            return Err(format!("Malformed std hex address. Invalid account ID length. \"{}\"", data));
        }

        Ok(Address{
            workchain: i8::from_str_radix(vec[0], 10)
                .map_err(|err| format!("Couldn't parse workchain: {}", err))?,
            account_id: hex::decode(vec[1])
                .map_err(|err| format!("Couldn't parse account ID: {}", err))?
        })
    }

    pub fn from_str(data: &str) -> Result<Self, String> {
         if data.len() == 48 {
            Self::decode_std_base64(data)
        } else {
            Self::decode_std_hex(data)
        }
    }

    pub fn to_hex(&self) -> String {
        format!("{}:{}", self.workchain, hex::encode(&self.account_id))
    }

    pub fn to_base64(&self, bounceable: bool, test: bool, as_url: bool) -> Result<String, String> {
        let mut tag = if bounceable { 0x11 } else { 0x51 };
        if test { tag |= 0x80 };

        let mut vec = vec![tag];
        vec.extend_from_slice(&self.workchain.to_be_bytes());
        vec.extend_from_slice(&self.account_id);
       
        let mut crc = crc_any::CRC::crc16xmodem();
        crc.digest(&vec);
        vec.extend_from_slice(&crc.get_crc_vec_be());

        let result = base64::encode(&vec);

        if as_url {
            Ok(result.replace('/', "_").replace('+', "-"))
        } else {
            Ok(result)
        }
    }
}

const HELP: &str = "
Convert TON address
Usage convert_address <address> hex|base64 [-t] [-u] [-b]
    address - TON blockchain std address in any format
    hex - represent address in hex
    base64 - represent address in base64
    -t - add 'test' flag to address (only base64)
    -b - make bounceable address (only base64; default - non bounceable)
    -u - format as URL-compatible address (only base64)
    
Example. Make base64 bounceable address from hex
convert_address.exe -1:3333333333333333333333333333333333333333333333333333333333333333 base64 -b
";


fn main() {
    let args: Vec<String> = std::env::args().collect();

    if args.len() < 2 || args[1] == "-help" || args[1] == "-h" {
        println!("{}", HELP);
        return;
    }

    if args.len() < 3 {
        panic!("Not enough parameters");
    }

    let address = Address::from_str(&args[1]).unwrap();

    match args[2].as_str() {
        "hex" => {
            println!("{}", address.to_hex());
        },
        "base64" => {
            let test = args[3..].contains(&"-t".to_owned());
            let bounce = args[3..].contains(&"-b".to_owned());
            let url = args[3..].contains(&"-u".to_owned());

            println!("{}", address.to_base64(bounce, test, url).unwrap())
        },
        _ => panic!("Unknown address type")
    };
}
