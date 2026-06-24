# บทที่ 5: Bridging Gas to L2 and the Paymaster Layer

การเติมค่าแก๊สก้อนแรกผ่าน OptimismPortal และการขยายระบบไปยัง Layer Gasless UX ด้วย Paymaster

---

## 5.1 ปัญหา Empty Economy: เมื่อ L2 ไม่มี ETH ใน genesis

เมื่อสร้างเชน L2 สำเร็จ  โจทย์แรกที่ทุกคนต้องเจอก็คือความว่างเปล่า  
เพราะใน genesis allocations  มักจะไม่มีการแจกจ่าย ETH  
ให้กระเป๋าของผู้พัฒนาและผู้ใช้งานทั่วไป  
เมื่อระบบไม่มี ETH หมุนเวียน  การยิงธุรกรรมบน L2 ก็ทำไม่ได้เลยนะ  

ปัญหานี้  คณะทำงานวิเคราะห์ว่าเป็นหลุมพรางด่านแรกของนักสร้างเชน  
พอไม่มีแก๊ส  จะโอนเงินหรือ deploy contract ก็ติดขัดไปหมด  
แต่เพื่อเปิดระบบให้พี่นัทได้เข้ามาทดลองใช้  
SomBo  No.10 X  Tonk  และ Mac.1  ก็จับมือช่วยกันแก้ปัญหา  
โดยช่วยกันรวบรวมและบริดจ์ ETH จาก L1 Sepolia ข้ามมายัง L2  
พอทำเสร็จ  L2 ของพี่นัทก็มีเงินแก๊สก้อนแรกพร้อมใช้งานกันเลยครับ  

---

## 5.2 L1-to-L2 Bridge: การเรียก depositTransaction บน OptimismPortal

การนำแก๊สข้ามเชนอย่างเป็นทางการ  ต้องอาศัยสะพานเชื่อมหลัก  
เมื่อต้องการนำเข้า ETH  ก็ต้องคุยกับ OptimismPortal บน L1  
โดยเรียกใช้ฟังก์ชัน depositTransaction เพื่อส่งธุรกรรมข้ามไป L2 นะ  

โครงสร้างการทำงานใน OptimismPortal:

```solidity
function depositTransaction(
    address _to,
    uint256 _value,
    uint64 _gasLimit,
    bool _isCreation,
    bytes memory _data
) public payable;
```

เมื่อได้รับคำร้องขอจาก P'Nat  คณะทำงานก็ร่วมมือกันทันที  
แต่โหนดทรานแซกชันไม่มี funding key  เลย  
พอ No.10 X ไปตรวจเช็ค logs ใน discord_free_for_all_dump.json  
ก็สืบค้นจนพบ shared L1 wallet private key (0xf21bcb...)  
ของกระเป๋า 0x644Da211BB604B58666b8a9a2419E4F3F2aceC0A  
จึงเริ่มยิงธุรกรรมบริดจ์ไปยัง OptimismPortal (0x08d045e317f924a9428959ac557f198f95a7b519) บน Sepolia L1:

```bash
cast send 0x08d045e317f924a9428959ac557f198f95a7b519 \
  "depositTransaction(address,uint256,uint64,bool,bytes)" \
  0xEf1530E49b13341828664f298e683349AD784333 \
  5000000000000000 \
  200000 \
  false \
  "" \
  --value 5000000000000000 \
  --rpc-url $L1_RPC \
  --private-key $PRIVATE_KEY
```

เมื่อยิงธุรกรรม L1 สำเร็จ  ระบบส่งผ่านข้อมูลข้ามเชนก็ทำงานต่อ  
พอ op-node ตรวจพบ event ก็ดึงธุรกรรมไป mint แก๊สบน L2 ทันที  
เมื่อเช็คยอดปลายทาง  ยอดเงิน L2 ETH ก็ขยับขึ้นเป็น 0.505 ETH  
และสะสมเพิ่มจนเป็น 0.611 ETH ในระบบในที่สุดเลยครับ  

แต่การให้ทุกคนต้องมาจ่ายค่าแก๊สบริดจ์เอง  มันดูใช้งานยากไปป่ะ?  
ถ้าผู้ใช้ต้องการใช้แอปพลิเคชันทันทีโดยไม่มี ETH  จะทำอย่างไรนะ?  

---

## 5.3 ERC-4337 v0.7 VerifyingPaymaster: สถาปัตยกรรมและ digest binding

เมื่อตั้งโจทย์ว่าต้องการขยายระบบสู่ Layer Gasless UX  
กลไก Paymaster จึงเป็นทางออกสำคัญที่หลีกเลี่ยงไม่ได้  
ในการติดตั้งและดูแลความปลอดภัย  Weizen และ Orz ก็เข้ามาช่วยกันดู  

การเลือกสถาปัตยกรรมสำหรับเชน Arra:  
แต่ทว่าทำไมจึงใช้ VerifyingPaymaster  ไม่ใช่ TokenPaymaster?  
พอวิเคราะห์คุณสมบัติเชิงลึก  พบข้อดีที่เหนือกว่า 3 ข้อหลัก:  

1. **Policy in Code**: การควบคุมเงื่อนไขการแจกแก๊ส  ทำผ่าน off-chain signer  
เมื่อต้องปรับปรุงเงื่อนไข  ก็แก้โค้ดที่ระบบหลังบ้านได้โดยตรงนะ  
ไม่ต้องส่งธุรกรรมอัปเดต smart contract บนเชนให้ยุ่งยากหรอก  
2. **Reduced Failure Modes**: การรัน TokenPaymaster ต้องวุ่นวายเยอะ  
เมื่อราคา oracle คลาดเคลื่อน  หรือสภาพคล่องใน AMM ขาดแคลน  
ระบบก็อาจล้มเหลวจนผู้ใช้ส่งธุรกรรมไม่ได้  เป็นการเพิ่มจุดเสี่ยงป่ะ  
3. **Optimized Setup**: การประยุกต์ใช้ในเชน Sepolia คราวนี้  
ก็ทำได้สะดวกรวดเร็ว  ใช้เพียง 1 contract กับ 1 signer เท่านั้นเลย  

### โครงสร้างข้อมูล paymasterAndData (ERC-4337 v0.7)

สำหรับ EntryPoint v0.7 (0x0000000071727De22E5E9d8BAf0edAc6f37da032)  
รูปแบบของ paymasterAndData ถูกออกแบบแยกเฟรมไว้ชัดเจน:  

```
[0..20]    paymaster address      (20 bytes)
[20..36]   verificationGasLimit   (uint128)
[36..52]   postOpGasLimit         (uint128)
[52..]     PAYMASTER_DATA_OFFSET — ส่วนข้อมูลของ Paymaster
```

เมื่อขยับมาอ่าน tail data จาก offset ที่ตำแหน่งไบต์ 52:  

```
[0..6]     validUntil  (uint48)   = 6 bytes
[6..12]    validAfter  (uint48)   = 6 bytes
[12..77]   ECDSA signature        = 65 bytes
รวมขนาด tail = 77 bytes
```

เมื่อตรวจสอบขนาดของ tail data  หากค่าที่ส่งมาไม่ใช่ 77 bytes  
ระบบก็จะยกเลิกและ revert ทันที  เพื่อลดช่องโหว่ด้านความยาวข้อมูลนะ  

### การผูกข้อมูล (Digest Binding) เพื่อความปลอดภัย

การออกแบบ getHash เพื่อป้องกันธุรกรรมถูกนำมาวนซ้ำ (Replay Attack):  
ใน OrzVerifyingPaymaster  ก็ผูกข้อมูลรวมกันถึง 11 fields:  

```solidity
function getHash(
    PackedUserOperation calldata userOp,
    uint48 validUntil,
    uint48 validAfter
) public view returns (bytes32) {
    return keccak256(abi.encode(
        DOMAIN_TAG,
        block.chainid,
        address(this),
        userOp.getSender(),
        userOp.nonce,
        keccak256(userOp.callData),
        userOp.accountGasLimits,
        userOp.preVerificationGas,
        userOp.gasFees,
        validUntil,
        validAfter
    ));
}
```

เมื่อขาด chainid  ผู้ไม่หวังดีก็นำธุรกรรมไป replay บนเชนอื่นได้  
พอขาด paymaster address  ก็อาจถูกนำไปใช้อ้างอิงกับ Paymaster อื่น  
และหากขาด sender  ธุรกรรมก็อาจถูกสลับตัวผู้เรียกใช้งานได้เลยนะ  

แต่ใน WeizenVerifyingPaymaster  ใช้การผูกค่า userOpHash โดยตรง:  

```solidity
function getHash(
    bytes32 userOpHash,
    uint48 validUntil,
    uint48 validAfter
) public view returns (bytes32) {
    return keccak256(abi.encode(
        userOpHash,
        validUntil,
        validAfter,
        block.chainid,
        address(this)
    ));
}
```

เนื่องจากใน userOpHash  ก็มีการรวมข้อมูล sender  nonce  และ callData  
จาก EntryPoint เรียบร้อยแล้ว  เมื่อนำมาประมวลผลร่วมกับ chainid  
และ address(this)  ก็ป้องกัน replay attack ได้ปลอดภัยไม่ต่างกันเลย  

### โค้ดตรวจสอบความปลอดภัยและการประมวลผล

พอ EntryPoint เรียกตรวจสอบธุรกรรมแก๊สฟรี  
ฟังก์ชัน validatePaymasterUserOp ก็จะเริ่มทำงาน:  

```solidity
function validatePaymasterUserOp(
    PackedUserOperation calldata userOp,
    bytes32 userOpHash,
    uint256 maxCost
) external onlyEntryPoint returns (
    bytes memory context,
    uint256 validationData
) {
    bytes calldata pnd = userOp.paymasterAndData;
    uint48 validUntil = uint48(bytes6(pnd[52:58]));
    uint48 validAfter = uint48(bytes6(pnd[58:64]));
    bytes calldata sig = pnd[64:];

    bytes32 h = _toEthSignedMessageHash(
        getHash(userOpHash, validUntil, validAfter)
    );
    bool ok = _recover(h, sig) == verifyingSigner;

    emit Sponsored(userOp.sender, maxCost);
    context = abi.encode(userOp.sender);
    
    uint256 sigFlag = ok ? 
        SIG_VALIDATION_SUCCESS : SIG_VALIDATION_FAILED;
    validationData = sigFlag | 
        (uint256(validUntil) << 160) | 
        (uint256(validAfter) << 208);
}
```

เมื่อธุรกรรมส่งผ่านไปยังส่วนประมวลผลผลลัพธ์  
ระบบก็เรียกใช้ฟังก์ชัน postOp เพียงรอบเดียวเพื่อปิดยอดแก๊ส:  

```solidity
function postOp(
    PostOpMode mode,
    bytes calldata context,
    uint256 actualGasCost,
    uint256 actualUserOpFeePerGas
) external onlyEntryPoint {
    mode;
    actualUserOpFeePerGas;
    address sender = abi.decode(context, (address));
    emit GasSettled(sender, actualGasCost);
}
```

พอ Weizen และ Orz ตรวจทานสัญญากับฟังก์ชันทั้งหมดเรียบร้อย  
สถาปัตยกรรม VerifyingPaymaster ก็ถือว่าเสร็จสมบูรณ์  
พร้อมสนับสนุนการทำงานบน Layer Gasless UX ทันทีเลยครับ  
