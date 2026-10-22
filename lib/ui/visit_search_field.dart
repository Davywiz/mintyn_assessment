import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'visit_theme.dart';

class VisitSearchField extends HookWidget {
  const VisitSearchField({
    super.key,
    required this.query,
    required this.onChanged,
  });
  final String query;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: query);
    final focus = useFocusNode();
    // Riverpod owns the query; Hooks own the field's editing and focus state.
    // Seed on mount, and reconcile only genuine external query changes so normal
    // typing keeps the keyboard's selection and composing region intact.
    useEffect(() {
      if (controller.text != query) {
        controller.value = TextEditingValue(
          text: query,
          selection: TextSelection.collapsed(offset: query.length),
        );
      }
      return null;
    }, [query, controller]);
    useListenable(controller);
    useListenable(focus);
    // Figma's visible field grows from 44dp to 66dp at 200% text.
    // Keep 2dp above/below it inside the real 48dp minimum tap region.
    final height = math.max(
      VisitLayout.minTapTarget,
      VisitLayout.minTapTarget +
          (MediaQuery.textScalerOf(context).scale(16) - 16) * 22 / 16,
    );
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            top: 2,
            bottom: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: focus.hasFocus
                      ? VisitColors.accent
                      : VisitColors.border,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          TextField(
            key: const ValueKey('search-visits'),
            controller: controller,
            focusNode: focus,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              fontSize: 16,
              height: 21 / 16,
              letterSpacing: 0,
              color: VisitColors.ink,
            ),
            decoration: InputDecoration(
              hintText: 'Search visits',
              hintStyle: const TextStyle(color: VisitColors.secondary),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.fromLTRB(
                40,
                12,
                controller.text.isEmpty ? 12 : VisitLayout.minTapTarget,
                12,
              ),
            ),
          ),
          Positioned(
            left: 12,
            child: IgnorePointer(
              child: SvgPicture.asset(
                'assets/icons/search.svg',
                width: 20,
                height: 20,
                excludeFromSemantics: true,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            Positioned(
              right: 0,
              child: Semantics(
                label: 'Clear search',
                button: true,
                child: InkResponse(
                  onTap: () {
                    controller.clear();
                    onChanged('');
                    focus.requestFocus();
                  },
                  child: SizedBox(
                    width: VisitLayout.minTapTarget,
                    height: math.max(VisitLayout.minTapTarget, height),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/clear.svg',
                        width: 20,
                        height: 20,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
