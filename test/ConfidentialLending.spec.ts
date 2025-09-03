import { expect } from "chai";
import { ethers, fhevm } from "hardhat";
import { FhevmType } from "@fhevm/hardhat-plugin";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

describe("ConfidentialLending (FHEVM)", function () {
  let owner: HardhatEthersSigner;
  let alice: HardhatEthersSigner;
  let bob: HardhatEthersSigner;
  let lending: any;
  let addr: string;

  beforeEach(async () => {
    [owner, alice, bob] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory("ConfidentialLending");
    lending = await Factory.deploy();
    addr = await lending.getAddress();
  });

  it("deposit → borrow within LTV → debt updates", async () => {
    // Alice deposits 1000
    const enc1000 = await fhevm.createEncryptedInput(addr, alice.address).add64(1000).encrypt();
    await (await lending.connect(alice).deposit(enc1000.handles[0], enc1000.inputProof)).wait();

    // Alice borrows 400 (<= 50% of 1000 → allowed)
    const enc400 = await fhevm.createEncryptedInput(addr, alice.address).add64(400).encrypt();
    await (await lending.connect(alice).borrow(enc400.handles[0], enc400.inputProof)).wait();

    const encDebt = await lending.getDebt(alice.address);
    const clearDebt = await fhevm.userDecryptEuint(FhevmType.euint64, encDebt, addr, alice);
    expect(clearDebt).to.eq(400);
  });

  it("fail-closed when borrowing above LTV; debt unchanged", async () => {
    // deposit 1000
    const enc1000 = await fhevm.createEncryptedInput(addr, alice.address).add64(1000).encrypt();
    await (await lending.connect(alice).deposit(enc1000.handles[0], enc1000.inputProof)).wait();

    // first borrow 400
    const enc400 = await fhevm.createEncryptedInput(addr, alice.address).add64(400).encrypt();
    await (await lending.connect(alice).borrow(enc400.handles[0], enc400.inputProof)).wait();

    // try over-borrow 200 more → would exceed 50% LTV → executed = 0
    const enc200 = await fhevm.createEncryptedInput(addr, alice.address).add64(200).encrypt();
    await (await lending.connect(alice).borrow(enc200.handles[0], enc200.inputProof)).wait();

    const encDebt = await lending.getDebt(alice.address);
    const clearDebt = await fhevm.userDecryptEuint(FhevmType.euint64, encDebt, addr, alice);
    expect(clearDebt).to.eq(400); // unchanged
  });

  it("accrue interest 1% then repay; debt goes to 0", async () => {
    // deposit 1000 and borrow 400
    const enc1000 = await fhevm.createEncryptedInput(addr, alice.address).add64(1000).encrypt();
    await (await lending.connect(alice).deposit(enc1000.handles[0], enc1000.inputProof)).wait();

    const enc400 = await fhevm.createEncryptedInput(addr, alice.address).add64(400).encrypt();
    await (await lending.connect(alice).borrow(enc400.handles[0], enc400.inputProof)).wait();

    // owner accrues 1% interest for Alice → 404
    await (await lending.connect(owner).accrueInterest(alice.address)).wait();

    let encDebt = await lending.getDebt(alice.address);
    let clearDebt = await fhevm.userDecryptEuint(FhevmType.euint64, encDebt, addr, alice);
    expect(clearDebt).to.eq(404);

    // Alice repays 405 → executed repay min(405,404)=404 → debt==0
    const enc405 = await fhevm.createEncryptedInput(addr, alice.address).add64(405).encrypt();
    await (await lending.connect(alice).repay(enc405.handles[0], enc405.inputProof)).wait();

    encDebt = await lending.getDebt(alice.address);
    clearDebt = await fhevm.userDecryptEuint(FhevmType.euint64, encDebt, addr, alice);
    expect(clearDebt).to.eq(0);
  });
});
