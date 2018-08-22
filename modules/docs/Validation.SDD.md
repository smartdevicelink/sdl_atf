# Validation SW Detail Design

## 1 Introduction
The document is intended to support software developers,
maintenance and integration engineers with sufficient,
detailed information concerning the design, development and
deployment concepts, to accomplish their respective tasks without reliance on the authors.

## 1.1 Rationale
Validation implements ATF Architectural Solution according to [ATF SW Architecture](https://smartdevicelink.com/en/guides/pull_request/93dee199f30303b4b26ec9a852c1f5261ff0735d/atf/components-view/#test-base)

## 1.2 Scope
Validation extracted as a separate component for:

- Test cases consecutive execution
- Each test case verification check:
  - User Script expectation
  - SDL executable status monitoring

## 1.3 Abbreviations and definitions

*RPC* - Remote Procedure Call.

*Mobile API* -  set of RPCs defined for SDLCore-to-Mobile communication.

*HMI API* -  set of RPCs defined for SDLCore-to-HMI communication.

## 2. Component detail design
## 2.1 Design solutions
The following design approaches and pattern was used for Validator:

- `load_schema` is a Facade class for validator loading and RPC validation.

## 2.2 Class Structure
The following UML class digram shows the component classes structure.

![Class diagram](../../../modules/docs/assets/validation_class_diagram.svg)

*General Note:* Due to Lua language specifics - classes on the diagram means lua tables with a methods.

For more information about class digram follow:

- <http://www.uml-diagrams.org/class-diagrams-overview.html>
- <https://sourcemaking.com/uml/modeling-it-systems/structural-view/class-diagram>

## 2.3 Sequence diagram
The following UML sequence digram shows how objects operate with one another and in what order.

![Sequence diagram](../../../modules/docs/assets/validation_seq_diagram.svg)

For more information about sequence digram follow:

- <http://www.uml-diagrams.org/sequence-diagrams.html>
- <https://sourcemaking.com/uml/modeling-it-systems/external-view/use-case-sequence-diagram>

## 2.4 State chart diagram
*Validation has no specific states to declare.*

## 3. Component Interfaces
## 3.1 Public interfaces description
*Validation* provides functionality with following interfaces:

- `load_schema`
- `schema_validation`
- `api_loader`

## 3.2 Internal interfaces description
Module has no internal interfaces.

## 3.3 Derived interfaces and dependencies
*Validation* requires following modules:

- `xml`
- `json`

## 4. Component data and resources
## 4.1 Element Data Structure
Component provides following data:

- API schema from the xml file provided by `api_loader.init`
- RPC validation table are provided by `schema_validation.CreateSchemaValidator`


## 4.2 Resource usage
*Validation* requires Mobile and HMI xml files.
This files shall be located in a *data* folder.

## 5.1 References
N/A

## 5.2 Document history

- In the master branch
  - <https://github.com/smartdevicelink/sdl_atf/commits/master/modules/docs/Validation.SDD.md>
- In the development branch
  - <https://github.com/smartdevicelink/sdl_atf/commits/develop/modules/docs/Validation.SDD.md>
- In the local branch
  - <https://github.com/pestOO/sdl_atf/commits/feature/SDD_template/modules/docs/Validation.SDD.md>