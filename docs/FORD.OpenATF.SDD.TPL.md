# INSTRUCTION
------ Design document template explanation -------
This is a SW Detailed Design template for each ATF component update.
The original QCA template with more detail description is available at Luxoft portal
https://adc.luxoft.com/confluence/display/PORTAL/Software+Detailed+Design+Template

---------------------- HOWTO -----------------------
For adding new component documentation please follow this steps:
1. Copy this document to the 'doc' subdirectory in the Component working directory with a new name.
   The name of the document shall stat with a component name for correct listing in a generated output.
        Note: SDD will not be according to QCA Documentation Control Guideline due to ldoc generation specifics.
    - Example:
       + modules/utils/Utils.SDD.md
  - https://adc.luxoft.com/confluence/display/PORTAL/Documentation+Control+Guideline#DocumentationControlGuideline-DocumentNaming
2. Replace <!Component Name> with a correct naming according to SAD naming
3. Replace blocks marked as following with a content according to instructions in these blocks
  - Each block starts as <!!!!!!!!!!!BEGIN_INSTRUCTION!!!!!!!!!!!!!>
  - Each block ends   as <!!!!!!!!!!!!END_INSTRUCTION!!!!!!!!!!!!!!>
  - If chapter content is not applicable for a Component update it with "Not applicable, since/because of <Reason>."
4. Update source code ldoc comments for mentioning entities in the following SDD chapter:
  - Public and private interfaces from chapter 3
  - Data types from chapter 4.2
  Note: See modules/schema_validation.lua as an example
5. Remove this instruction explanation from beginning to {END_INSTRUCTION} tags

General notes/reminders:
- Look at "modules/docs/Validation SW Detail Design.md" example
- Commit both: images and them source to the git repository
- SDD file extension shall be 'md' 
- the preferable path for SDD is modules/COMPONENT/docs
- the preferable path for SDD images and there source files is modules/COMPONENT/docs/assets
- Foe adding lua file to documentation start this lua file with a following ldoc comment ('---')
- For adding images in MD format follow https://www.stack.nl/~dimitri/doxygen/manual/markdown.html#md_images
- As a tool for image preparing could be used Gliffy digram
      https://adc.luxoft.com/confluence/pages/createpage.action?showGliffyMacro=true&fromCreateDialog=true&spaceKey=APPLINK
    OR plantuml diagram
      http://plantuml.com/state.html
- empty string requires before the lists for correct parsing by ldoc

Known issues:
- Markdown tables are not working properly in md files

For more information, please follow:
- LDoc documentation
    https://stevedonovan.github.io/ldoc/manual/doc.md.html
- Markdown sintaxyx by doxygen
    http://www.stack.nl/~dimitri/doxygen/manual/markdown.html
- Text-base UML tool
    http://plantuml.com/
- Article "Providing design documentation with code changes"
    https://github.com/smartdevicelink/sdl_core/wiki/Providing-design-documentation-with-code-changes
-------{END_INSTRUCTION}-------

# <!Component Name> SW Detail Design

## 1 Introduction
The document is intended to support software developers,
maintenance and integration engineers with sufficient,
detailed information concerning the design, development and
deployment concepts, to accomplish their respective tasks without reliance on the authors.

## 1.1 Rationale
<!Component Name> implements ATF Architectural Solution according to [ATF SW Architecture](https://smartdevicelink.com/en/guides/pull_request/93dee199f30303b4b26ec9a852c1f5261ff0735d/atf/components-view/)

## 1.2 Scope
<!Component Name> extracted as a separate component for:

<!!!!!!!!!!!BEGIN_INSTRUCTION!!!!!!!!!!!!!>
Here need to be added a reason and short description of the components functionality
Example:
  Security Manager component extracted as a separate module for
  Ford channel data protection.
  This components is used to :
  - Provide security communications
  - Protect income and outcome business layer data from interception
  - Verify the relation between a mobile application certificate and its owner
<!!!!!!!!!!!END_INSTRUCTION!!!!!!!!!!!!!>

## 1.3 Abbreviations and definitions

<!!!!!!!!!!!BEGIN_INSTRUCTION!!!!!!!!!!!!!>
Here need to be added all component-specific terms, as
*RPC* - Remote Procedure Call.
<!!!!!!!!!!!END_INSTRUCTION!!!!!!!!!!!!!>

## 2. Component detail design
## 2.1 Design solutions
The following design approaches and pattern was used for Validator:

<!!!!!!!!!!!BEGIN_INSTRUCTION!!!!!!!!!!!!!>
Here need to be added GoF (or other) SW design patterns,
technologies and approaches with short description
Example:
  - Command design pattern is used to treat requests as an object that provides
      possibility to add new request without existing code modification
  - Factory method pattern design used for SSLContext objects creation
      + It also guaranty correctness of SSLContext destruction by the
      same Compiled SecurityManger object
  - All database reading are cached by CacheManager class, which
      guaranty meeting timing contrariness
  - SQLite database was chosen as a lightweight, embedded, transactional SQL database engine
<!!!!!!!!!!!END_INSTRUCTION!!!!!!!!!!!!!>

## 2.2 Class Structure
The following UML class digram shows the component classes structure.

<!!!!!!!!!!!BEGIN_INSTRUCTION!!!!!!!!!!!!!>
Here need to be added class diagram
Example:
     ![Class diagram](../../../modules/docs/assets/validation_class_diagram.svg)
Note 1: Look at the path example - it's important to set the correct relative path
Note 2: Source files of diagram and output images need to be also committed to git.
<!!!!!!!!!!!END_INSTRUCTION!!!!!!!!!!!!!>

For more information about class digram follow:

- <http://www.uml-diagrams.org/class-diagrams-overview.html>
- <https://sourcemaking.com/uml/modeling-it-systems/structural-view/class-diagram>

## 2.3 Sequence diagram
The following UML sequence digram shows how objects operate with one another and in what order.

<!!!!!!!!!!!BEGIN_INSTRUCTION!!!!!!!!!!!!!>
Here need to be added class diagram
Example:
     ![Sequence diagram](../../../modules/docs/assets/validation_seq_diagram.svg)
<!!!!!!!!!!!END_INSTRUCTION!!!!!!!!!!!!!>

For more information about sequence digram follow:

- <http://www.uml-diagrams.org/sequence-diagrams.html>
- <https://sourcemaking.com/uml/modeling-it-systems/external-view/use-case-sequence-diagram>

## 2.4 State chart diagram
The following UML state digram shows the component life cycle states.

<!!!!!!!!!!!BEGIN_INSTRUCTION!!!!!!!!!!!!!>
Here need to be added class diagram
Example:
     ![State diagram](../../../modules/docs/assets/validation_state_diagram.svg)
     or
     *<!Component Name> has no specific states to declare.*
<!!!!!!!!!!!END_INSTRUCTION!!!!!!!!!!!!!>

For more information about class digram follow:

- <http://www.uml-diagrams.org/state-machine-diagrams.html>

## 3. Component Interfaces
## 3.1 Public interfaces description
<!Component Name> provides functionality with following interfaces:

<!!!!!!!!!!!BEGIN_INSTRUCTION!!!!!!!!!!!!!>
Here need to be added a list of external interfaces
Example:
    - `load_schema`
    - `schema_validation`
Note: Text surrounded by ` signs will be auto-added by ldoc
<!!!!!!!!!!!END_INSTRUCTION!!!!!!!!!!!!!>

## 3.2 Internal interfaces description
The following interfaces are provided by <!Component Name> for internal usage only:

<!!!!!!!!!!!BEGIN_INSTRUCTION!!!!!!!!!!!!!>
Here need to be added a list of external interfaces
Example:
    - `api_loader`
Note: Text surrounded by ` signs will be auto-added by ldoc
<!!!!!!!!!!!END_INSTRUCTION!!!!!!!!!!!!!>


## 3.3 Derived interfaces and dependencies
<!Component Name> requires following modules:

<!!!!!!!!!!!BEGIN_INSTRUCTION!!!!!!!!!!!!!>
Here need to be added a list of libraries or other components
Example:
    -  OpenSSL library v 1.0.1g and higher to meet TLS cipher restricts
    - `xml`
    - `json`
<!!!!!!!!!!!END_INSTRUCTION!!!!!!!!!!!!!>

## 4. Component data and resources
## 4.1 Element Data Structure
<!Component Name> provides following data:

<!!!!!!!!!!!BEGIN_INSTRUCTION!!!!!!!!!!!!!>
Here need to be added a list of component data types
Example:
    - API schema from the xml file provided by `api_loader.init`
    - RPC validation table are provided by `schema_validation.CreateSchemaValidator`
All link will be auto-added by doxygen
<!!!!!!!!!!!END_INSTRUCTION!!!!!!!!!!!!!>

## 4.2 Resource usage

<!!!!!!!!!!!BEGIN_INSTRUCTION!!!!!!!!!!!!!>
Here need to be added all resource-related information
All file, database or network reading
An amount of processing by component data
Example:
     Resumption uses QBD/JSON database with configurable limitation 10 Mb
     Request Controller Handle a configured amount of RPCs:
       - A XXX count of messages from application in NONE level
              + <LINK_TO_REQURMENT_XXX>
       - A YYY count of messages per second for each application
              + <LINK_TO_REQURMENT_YYY>
 (!) In case of no such restrict it need to be clarified  (!)
<!!!!!!!!!!!END_INSTRUCTION!!!!!!!!!!!!!>

## 5.1 References
<!!!!!!!!!!!BEGIN_INSTRUCTION!!!!!!!!!!!!!>
Here need to be added a list of all related to component functionality
references, including 3d-party libraries, documentation, requirements 
Example:
  -  [OpenSSL API](https://www.openssl.org/docs/manmaster/ssl/)
  -  [SQLite Documents](https://www.sqlite.org/docs.html)
<!!!!!!!!!!!END_INSTRUCTION!!!!!!!!!!!!!>

## 5.2 Document history
<!!!!!!!!!!!BEGIN_INSTRUCTION!!!!!!!!!!!!!>
Example for this template:
- In the master branch
  - <https://github.com/smartdevicelink/sdl_atf/commits/master/docs/FORD.OpenATF.SDD.TPL.md>
- In the development branch
  - <https://github.com/smartdevicelink/sdl_atf/commits/develop/docs/FORD.OpenATF.SDD.TPL.md>
- In the local branch
  - <https://github.com/pestOO/sdl_atf/commits/feature/SDD_template/docs/FORD.OpenATF.SDD.TPL.md>
<!!!!!!!!!!!END_INSTRUCTION!!!!!!!!!!!!!>