CREATE TABLE `exDB`.`customers` (
  `idcustomers` INT NOT NULL,
  `name` VARCHAR(45) NOT NULL,
  `address` VARCHAR(45) NOT NULL,
  `stripe_account_id` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`idcustomers`));

CREATE TABLE `exDB`.`transactions` (
  `idtransactions` INT NOT NULL AUTO_INCREMENT,
  `event_type` VARCHAR(45) NOT NULL,
  `stripe_hook_transaction_id` VARCHAR(45) NOT NULL,
  `timestamp` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `customer_fk` INT NOT NULL,
  PRIMARY KEY (`idtransactions`));

ALTER TABLE `exDB`.`transactions` 
ADD INDEX `customer foreight key_idx` (`customer_fk` ASC) VISIBLE;
ALTER TABLE `exDB`.`transactions` 
ADD CONSTRAINT `customer foreign key`
  FOREIGN KEY (`customer_fk`)
  REFERENCES `exDB`.`customers` (`idcustomers`)
  ON DELETE NO ACTION
  ON UPDATE NO ACTION;

INSERT INTO `exDB`.`customers` (`name`, `address`, `stripe_account_id`) VALUES ('joes java', '111 silverstream road', 'acct_1K1ZebPw7IujTWEe');

ALTER TABLE `exDB`.`transactions` 
ADD COLUMN `outgoing_transfer_id` VARCHAR(45) NULL DEFAULT NULL AFTER `customer_fk`;