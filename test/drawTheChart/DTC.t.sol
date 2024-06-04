// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {stdJson} from "forge-std/StdJson.sol";
import {Test} from "forge-std/Test.sol";
import {ScriptHelper} from "@WtchTwrTesting/common/ScriptHelper.sol";
import {console} from "forge-std/console.sol";
import {DrawTheChart} from "@DrawTheChart/DrawTheChart.sol";
import {Merkle} from "murky/src/Merkle.sol";
import {TestUtils} from "@WtchTwrTesting/testUtils/testUtils.sol";
import {ProtocolWallet} from "@WtchTwrDefi/DummyProtocolWallet.sol";

contract DTCClaim is ScriptHelper, TestUtils {
    using stdJson for string;

    DrawTheChart dtc;

    uint256 constant baseBlockTime = 2 minutes;
    uint256 public gameDurationInBlocks = (24 hours) / baseBlockTime;
    string public police = "\xF0\x9F\x91\xAE";
    string public stonks = "\xF0\x9F\x92\xB0";
    string public symbolEmoji = "\xF0\x9F\x94\xAE";
    ProtocolWallet wallet = new ProtocolWallet();
    Merkle private m = new Merkle();

    string private inputPath = "/test/drawTheChart/target/input.json";
    string private outputPath = "/test/drawTheChart/target/output.json";
    string private merkleOutputPath =
        "/test/drawTheChart/target/merkle-proof.json";
    string private elements =
        vm.readFile(string(abi.encodePacked(vm.projectRoot(), inputPath)));
    string[] private types = elements.readStringArray(".types");
    uint256 private count = elements.readUint(".count");
    bytes32[] private leafs = new bytes32[](count);

    string[] private inputs = new string[](count);
    string[] private outputs = new string[](count);

    string private output;

    error DepositSumIncorrect(
        uint256 totalDeposits,
        uint256 expectedTotalDepositsMinusFees
    );

    function setUp() public {
        getAccountsFromJson();
        dtc = new DrawTheChart(address(this));
        address creator = address(
            uint160(uint256(keccak256(abi.encodePacked("dummy1"))))
        );
        vm.deal(creator, 1e18);
        vm.startPrank(creator);
        dtc.createGame(
            uint128(block.number + 1),
            uint128(block.number + 2),
            1e18, //using 1 eth for ease of use in test, real value will be 1-2$ of eth
            WETH,
            10,
            true
        );
        vm.stopPrank();
        emit log_string(
            string(
                abi.encodePacked(
                    police,
                    " Creating Game with start @ block ",
                    vm.toString(block.number + 1),
                    " and end @ block ",
                    vm.toString(block.number + 2)
                )
            )
        );
    }

    function testDrawTheChartCreateGameAndClaimAll() public {
        address[] memory accounts = getAccountsFromJsonProof();
        enterGame(accounts);

        vm.roll(3);
        require(dtc.isGameEndable(0), "game cannot be ended yet");

        vm.startPrank(dtc.getCreator(0));
        dtc.endGame(0);
        require(dtc.isGameEnded(0) == true, "failed to end game");

        emit log_string(
            string(
                abi.encodePacked(
                    police,
                    " Ending Game at block ",
                    vm.toString(block.number)
                )
            )
        );
        bytes32 root = getJsonRoot();
        dtc.setMerkleRootForGame(root, 0);
        dtc.getEntriesForGame(uint64(0));

        verifyProofs(root);

        vm.stopPrank();

        address creator = dtc.getCreator(0);
        vm.startPrank(creator);
        uint256 balB = address(creator).balance;
        (bool success, uint256 amount) = dtc.claimCreatorFees(0);
        uint256 balA = address(creator).balance - balB;
        require(balA == amount, "Claimed a different amount than intended");
        require(success == true);
        emit log_string(
            string(
                abi.encodePacked(
                    "       ",
                    checkmark,
                    " ",
                    gearEmoji,
                    " Claimed: ",
                    vm.toString(amount),
                    " ETH ==> ",
                    vm.toString(creator)
                )
            )
        );
        uint256 balDTC = address(dtc).balance;
        require(
            balDTC - balA > 0,
            "Did not leave enough left over for protocol fee"
        );
        vm.stopPrank();
        emit log_string(
            string(
                abi.encodePacked(
                    "       ",
                    checkmark,
                    " ",
                    symbolEmoji,
                    " Protocol Fee: ",
                    vm.toString(balDTC)
                )
            )
        );
        dtc.claimProtocolFees(0, address(wallet));
    }

    function generateMerkleProof() public returns (bytes32) {
        emit log_string(
            string(
                abi.encodePacked(
                    gearEmoji,
                    " Generating Merkle Proof for ",
                    inputPath
                )
            )
        );

        for (uint256 i = 0; i < count; ++i) {
            string[] memory input = new string[](types.length);
            bytes32[] memory data = new bytes32[](types.length);

            for (uint256 j = 0; j < types.length; ++j) {
                if (compareStrings(types[j], "address")) {
                    address value = elements.readAddress(
                        getValuesByIndex(i, j)
                    );
                    data[j] = bytes32(uint256(uint160(value)));
                    input[j] = vm.toString(value);
                } else if (compareStrings(types[j], "uint")) {
                    uint256 value = vm.parseUint(
                        elements.readString(getValuesByIndex(i, j))
                    );
                    data[j] = bytes32(value);
                    input[j] = vm.toString(value);
                }
            }

            leafs[i] = keccak256(
                bytes(abi.encodePacked(keccak256((abi.encode(data)))))
            );
            inputs[i] = stringArrayToString(input);
        }

        for (uint256 i = 0; i < count; ++i) {
            string memory proof = bytes32ArrayToString(m.getProof(leafs, i));
            string memory root = vm.toString(m.getRoot(leafs));
            string memory leaf = vm.toString(leafs[i]);
            string memory input = inputs[i];

            outputs[i] = generateJsonEntries(input, proof, root, leaf, i);
        }

        output = stringArrayToArrayString(outputs);
        vm.writeFile(
            string(abi.encodePacked(vm.projectRoot(), outputPath)),
            output
        );

        return m.getRoot(leafs);
    }

    function getAccountsFromJson() internal view returns (address[] memory) {
        string memory merkleOutput = vm.readFile(
            string(abi.encodePacked(vm.projectRoot(), outputPath))
        );
        uint256 entrants = merkleOutput.readUint(".count");
        address[] memory accounts = new address[](entrants);
        for (uint256 i = 0; i < entrants; i++) {
            string memory accessor = string(
                abi.encodePacked(".values.", vm.toString(i))
            );
            accounts[i] = merkleOutput.readAddress(
                string(abi.encodePacked(accessor, ".inputs[0]"))
            );
        }

        return accounts;
    }

    function getAccountsFromJsonProof()
        internal
        view
        returns (address[] memory)
    {
        string memory merkleOutput = vm.readFile(
            string(abi.encodePacked(vm.projectRoot(), merkleOutputPath))
        );
        uint256 entrants = merkleOutput.readUint(".count");
        address[] memory accounts = new address[](2 * entrants);
        for (uint256 i = 0; i < entrants; i++) {
            string memory accessor = string(
                abi.encodePacked(".proofs.", vm.toString(i))
            );
            accounts[i] = merkleOutput.readAddress(
                string(abi.encodePacked(accessor, ".inputs.address"))
            );
        }
        for (uint256 i = entrants; i < 2 * entrants; i++) {
            accounts[i] = address(
                uint160(
                    uint256(
                        keccak256(abi.encodePacked(vm.toString(i), "dummy"))
                    )
                )
            );
        }

        return accounts;
    }

    function getJsonRoot() internal view returns (bytes32) {
        string memory merkleOutput = vm.readFile(
            string(abi.encodePacked(vm.projectRoot(), merkleOutputPath))
        );
        bytes32 root = merkleOutput.readBytes32(".proofs.0.root");
        return root;
    }

    function verifyProofs(bytes32 root) public returns (bool success) {
        string memory merkleOutput = vm.readFile(
            string(abi.encodePacked(vm.projectRoot(), merkleOutputPath))
        );
        uint256 entrants = merkleOutput.readUint(".count");
        // string[] memory inputTypes = elements.readStringArray('.types');
        uint256 totalWinnings;
        for (uint256 i = 0; i < entrants; i++) {
            //target values in json
            string memory accessor = string(
                abi.encodePacked(".proofs.", vm.toString(i))
            );

            //inputs
            address account = merkleOutput.readAddress(
                string(abi.encodePacked(accessor, ".inputs.address"))
            );
            uint256 amount = merkleOutput.readUint(
                string(abi.encodePacked(accessor, ".inputs.weiAmount"))
            );

            //proof
            bytes32[] memory proof = merkleOutput.readBytes32Array(
                string(abi.encodePacked(accessor, ".proof"))
            );

            //leaf
            bytes32 leaf = merkleOutput.readBytes32(
                string(abi.encodePacked(accessor, ".leaf"))
            );
            //verify proof
            success = m.verifyProof(root, proof, leaf);
            require(success, "unsuccessful proof validation");
            vm.startPrank(account);
            uint256 balB = address(account).balance;

            dtc.claimWinnings(account, 0, proof, uint128(amount), leaf);
            uint256 balA = address(account).balance - balB;
            require(balA == amount, "failed to claim correct winnings");
            totalWinnings += amount;
        }
        emit log_string(
            string(
                abi.encodePacked(
                    "       ",
                    checkmark,
                    " Successfully Verified Proof for ",
                    vm.toString(entrants),
                    " Accounts "
                )
            )
        );
        emit log_string(
            string(
                abi.encodePacked(
                    "       ",
                    stonks,
                    " Successfully Paid Out ",
                    vm.toString(totalWinnings),
                    " ETH "
                )
            )
        );
    }

    function enterGame(
        address[] memory accounts
    ) public returns (bool success) {
        uint256 balBefore = address(dtc).balance;

        for (uint256 i = 0; i < accounts.length; i++) {
            vm.deal(accounts[i], 1e18);
            DrawTheChart.ObservationData[24]
                memory predictedPrices = createPredictedPrices(1);
            vm.prank(accounts[i], accounts[i]);
            {
                (, , uint256 entriesIndex) = dtc.enterGame{value: 1e18}(
                    0,
                    keccak256(abi.encode(predictedPrices)),
                    ""
                );

                require(entriesIndex == i + 1, "wrong entry index");

                (, , , , uint128 totalDeposits, , , , , , , ) = dtc.getGame(0);

                uint256 expectedTotalDeposits = 1e18 *
                    dtc.getNumberOfPlayers(0);
                uint256 expectedTotalDepositsMinusFees = expectedTotalDeposits -
                    ((expectedTotalDeposits * dtc.getProtocolFeeForGame(0)) /
                        100);
                if (totalDeposits != expectedTotalDepositsMinusFees) {
                    revert DepositSumIncorrect(
                        totalDeposits,
                        expectedTotalDeposits
                    );
                }
            }
        }
        {
            emit log_string(
                string(
                    abi.encodePacked(
                        "       ",
                        littleMan,
                        " Total Number of Entrants: ",
                        vm.toString(accounts.length)
                    )
                )
            );
        }

        uint256 balAfter = address(dtc).balance - balBefore;
        uint256 length = dtc.getNumberOfPlayers(0);
        require(balAfter == 1e18 * length, "Not enough deposits Accumulated");
        return true;
        // uint256 _expectedTotalDeposits = 1e18 * dtc.getNumberOfPlayers(0);
        // uint256 expectedBalance =
        //     _expectedTotalDeposits - ((_expectedTotalDeposits * dtc.getProtocolFeeForGame(0)) / 100);
        // require(totalDeposits == expectedBalance, "game deposit mismatch with balance");
    }
}
