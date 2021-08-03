import { expect } from "chai";
import { ethers, waffle } from "hardhat";
import { Signer } from "ethers";
const { loadFixture } = waffle;

import { Greeter } from "../typechain";
import { greeterFixture } from "./shared/fixtures";

describe("Greeter", function() {
  let signers: Signer[];
  let greeter: Greeter;

  beforeEach(async function() {
    signers = await ethers.getSigners();

    ({ greeter } = await loadFixture(greeterFixture));
  });

  it("should return the new greeting once it's changed", async function() {
    expect(await greeter.greet()).to.equal("Hello, world!");

    await greeter.setGreeting("Hola, mundo!");
    expect(await greeter.greet()).to.equal("Hola, mundo!");
  });
});
